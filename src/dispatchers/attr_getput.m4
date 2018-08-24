dnl Process this m4 file to produce 'C' language file.
dnl
dnl If you see this line, you can ignore the next one.
/* Do not edit this file. It is produced from the corresponding .m4 source */
dnl
/*
 *  Copyright (C) 2017, Northwestern University and Argonne National Laboratory
 *  See COPYRIGHT notice in top-level directory.
 */
/* $Id: attribute.m4 2873 2017-02-14 02:58:34Z wkliao $ */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdlib.h>
#include <string.h>

#include <pnetcdf.h>
#include <dispatch.h>
#include <pnc_debug.h>
#include <common.h>

/*----< sanity_check_get() >-------------------------------------------------*/
/* This is an independent subroutine. Sanity check for attribute get APIs is
 * simpler, as attribute get APIs are independent subroutines.
 */
static int
sanity_check_get(PNC        *pncp,
                 int         varid,
                 const char *name)
{
    /* check whether variable ID is valid */
    if (varid != NC_GLOBAL && (varid < 0 || varid >= pncp->nvars))
        DEBUG_RETURN_ERROR(NC_ENOTVAR)

    /* sanity check for name */
    if (name == NULL || *name == 0) DEBUG_RETURN_ERROR(NC_EBADNAME)

    if (strlen(name) > NC_MAX_NAME) DEBUG_RETURN_ERROR(NC_EMAXNAME)

    return NC_NOERR;
}

/*----< sanity_check_put() >-------------------------------------------------*/
/* This is a collective subroutine. */
static int
sanity_check_put(PNC        *pncp,
                 int         varid,
                 const char *name)
{
    int err=NC_NOERR;

    /* file should be opened with writable permission */
    if (pncp->flag & NC_MODE_RDONLY)
        DEBUG_RETURN_ERROR(NC_EPERM)

    /* check whether variable ID is valid */
    if (varid != NC_GLOBAL && (varid < 0 || varid >= pncp->nvars))
        DEBUG_RETURN_ERROR(NC_ENOTVAR)

    if (name == NULL || *name == 0) /* name cannot be NULL or NULL string */
        DEBUG_RETURN_ERROR(NC_EBADNAME)

#ifdef NO_NC_GLOBAL_FILLVALUE
    /* See r3403 and RELEASE_NOTES 1.9.0 */
    if (varid == NC_GLOBAL && !strcmp(name, _FillValue))
        DEBUG_RETURN_ERROR(NC_EGLOBAL) /* global _FillValue is not allowed */
#endif

    if (strlen(name) > NC_MAX_NAME) /* name length */
        DEBUG_RETURN_ERROR(NC_EMAXNAME)

    /* check if the name string is legal for netcdf format */
    err = ncmpii_check_name(name, pncp->format);
    if (err != NC_NOERR) return err;

    return NC_NOERR;
}

/*----< check_EINVAL() >-------------------------------------------------*/
static int
check_EINVAL(PNC        *pncp,
             MPI_Offset  nelems,
             const void *buf)
{
    int err=NC_NOERR;

    /* nelems can be zero, i.e. an attribute with only its name */
    if (nelems > 0 && buf == NULL)
        DEBUG_RETURN_ERROR(NC_EINVAL) /* Null arg */

    if (nelems < 0 || (nelems > NC_MAX_INT && pncp->format <= NC_FORMAT_CDF2))
        DEBUG_RETURN_ERROR(NC_EINVAL) /* Invalid nelems */

    return NC_NOERR;
}

/*----< check_EBADTYPE_ECHAR() >---------------------------------------------*/
static int
check_EBADTYPE_ECHAR(PNC *pncp, MPI_Datatype itype, nc_type xtype)
{
    int err;

    /* the max external data type supported by CDF-5 is NC_UINT64 */
    if (xtype <= 0 || xtype > NC_UINT64)
        DEBUG_RETURN_ERROR(NC_EBADTYPE)

    /* For CDF-1 and CDF-2 files, only classic types are allowed. */
    if (pncp->format <= NC_FORMAT_CDF2 && xtype > NC_DOUBLE)
        DEBUG_RETURN_ERROR(NC_ESTRICTCDF2)

    /* No character conversions are allowed. */
    err = (((xtype == NC_CHAR) == (itype != MPI_CHAR)) ? NC_ECHAR : NC_NOERR);
    if (err != NC_NOERR) DEBUG_RETURN_ERROR(err)

    return NC_NOERR;
}

/*----< check_consistency_put() >--------------------------------------------*/
/* This is a collective subroutine and to be called in safe mode. */
static int
check_consistency_put(MPI_Comm      comm,
                      int           varid,
                      const char   *name,
                      nc_type       xtype,
                      MPI_Offset    nelems,
                      const void   *buf,
                      MPI_Datatype  itype,
                      int           err)
{
    int root_name_len, root_varid, minE, rank, mpireturn;
    char *root_name=NULL;
    nc_type root_xtype;
    MPI_Offset root_nelems;

    /* first check the error code, err, across processes */
    TRACE_COMM(MPI_Allreduce)(&err, &minE, 1, MPI_INT, MPI_MIN, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Allreduce");
    if (minE != NC_NOERR) return minE;

    MPI_Comm_rank(comm, &rank);

    /* check if attribute name is consistent among all processes */
    root_name_len = strlen(name) + 1;
    TRACE_COMM(MPI_Bcast)(&root_name_len, 1, MPI_INT, 0, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast root_name_len");

    root_name = (char*) NCI_Malloc((size_t)root_name_len);
    if (rank == 0) strcpy(root_name, name);
    TRACE_COMM(MPI_Bcast)(root_name, root_name_len, MPI_CHAR, 0, comm);
    if (mpireturn != MPI_SUCCESS) {
        NCI_Free(root_name);
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast");
    }
    if (err == NC_NOERR && strcmp(root_name, name))
        DEBUG_ASSIGN_ERROR(err, NC_EMULTIDEFINE_ATTR_NAME)
    NCI_Free(root_name);

    /* check if varid is consistent across all processes */
    root_varid = varid;
    TRACE_COMM(MPI_Bcast)(&root_varid, 1, MPI_INT, 0, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast");
    if (err == NC_NOERR && root_varid != varid)
        DEBUG_ASSIGN_ERROR(err, NC_EMULTIDEFINE_FNC_ARGS)

    /* check if xtype is consistent across all processes */
    root_xtype = xtype;
    TRACE_COMM(MPI_Bcast)(&root_xtype, 1, MPI_INT, 0, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast");
    if (err == NC_NOERR && root_xtype != xtype)
        DEBUG_ASSIGN_ERROR(err, NC_EMULTIDEFINE_ATTR_TYPE)

    /* check if nelems is consistent across all processes */
    root_nelems = nelems;
    TRACE_COMM(MPI_Bcast)(&root_nelems, 1, MPI_OFFSET, 0, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast");
    if (err == NC_NOERR && root_nelems != nelems)
        DEBUG_ASSIGN_ERROR(err, NC_EMULTIDEFINE_ATTR_LEN)

    /* check if buf contents is consistent across all processes */
    if (root_nelems > 0) { /* non-scalar attribute */
        /* note xsz is aligned, thus must use the exact size of buf */
        int itype_size, rank, buf_size;
        void *root_buf;

        MPI_Comm_rank(comm, &rank);
        MPI_Type_size(itype, &itype_size);
        buf_size = (int)root_nelems * itype_size;
        if (rank > 0) root_buf = (void*) NCI_Malloc(buf_size);
        else          root_buf = (void*)buf;

        TRACE_COMM(MPI_Bcast)(root_buf, root_nelems, itype, 0, comm);
        if (mpireturn != MPI_SUCCESS)
            return ncmpii_error_mpi2nc(mpireturn, "MPI_Bcast");
        if (err == NC_NOERR &&
            (root_nelems != nelems || memcmp(root_buf, buf, buf_size)))
            DEBUG_ASSIGN_ERROR(err, NC_EMULTIDEFINE_ATTR_VAL)
        if (rank > 0) NCI_Free(root_buf);
    }

    /* find min error code across processes */
    TRACE_COMM(MPI_Allreduce)(&err, &minE, 1, MPI_INT, MPI_MIN, comm);
    if (mpireturn != MPI_SUCCESS)
        return ncmpii_error_mpi2nc(mpireturn, "MPI_Allreduce");
    if (minE != NC_NOERR) return minE;

    return err;
}

include(`foreach.m4')dnl
include(`utils.m4')dnl

dnl
define(`APINAME',`ifelse(`$2',`',`ncmpi_$1_att$2',`ncmpi_$1_att_$2')')dnl
dnl
dnl
dnl GETPUT_ATT(get/put, iType)
dnl
define(`GETPUT_ATT',dnl
`dnl
/*----< APINAME($1,$2)() >---------------------------------------------------*/
/* ifelse(`$1',`get',`This is an independent subroutine.',`
 * This is a collective subroutine, all arguments should be consistent among
 * all processes.
 *
 * If attribute name has already existed, it means to overwrite the attribute.
 * In this case, if the new attribute is larger than the old one, this API
 * must be called when the file is in define mode. (This check should be done
 * at the driver.)
 *
 * Note from netCDF user guide:
 * Attributes are always single values or one-dimensional arrays. This works
 * out well for a string, which is a one-dimensional array of ASCII characters.
 *')
ifelse(`$2',`',` * The user buffer data type matches the external type defined in file.',
`$2',`text',` * This API never returns NC_ERANGE error, as text is not convertible to numerical types',` *')
 */
int
APINAME($1,$2)(int         ncid,
               int         varid,
               const char *name,
               ifelse(`$1',`put',`ifelse(`$2',`text',,`nc_type xtype,')
               MPI_Offset  nelems,   /* number of elements in buf */')
               ifelse(`$1',`put',`const') ifelse(`$2',`','void`,NC2ITYPE($2)) *buf)
{
    int err=NC_NOERR;
    PNC *pncp;
    ifelse(`$2',`text',`ifelse(`$1',`put',`nc_type xtype=NC_CHAR;')')
ifelse(`$2',`',`
    MPI_Datatype itype='ifelse(`$1',`get',`MPI_DATATYPE_NULL;',`ncmpii_nc2mpitype(xtype);'),
`$2',`long',`#if SIZEOF_LONG == SIZEOF_INT
    MPI_Datatype itype=MPI_INT;
#elif SIZEOF_LONG == SIZEOF_LONG_LONG
    MPI_Datatype itype=MPI_LONG_LONG_INT;
#endif',`    MPI_Datatype itype=ITYPE2MPI($2);')

    /* check if ncid is valid */
    err = PNC_check_id(ncid, &pncp);
    if (err != NC_NOERR) return err;

    /* sanity check for arguments */
    ifelse(`$1',`get',
    `err = sanity_check_get(pncp, varid, name);
    if (err != NC_NOERR) return err;',
    `err = sanity_check_put(pncp, varid, name);')

    ifelse(`$1',`put',`ifelse(`$2',`text',`',`/* check NC_EBADTYPE/NC_ECHAR */
    if (err == NC_NOERR) err = check_EBADTYPE_ECHAR(pncp, itype, xtype);')')

    /* check for nelems against buf for NC_EINVAL */dnl
    ifelse(`$1',`put',`
    if (err == NC_NOERR) err = check_EINVAL(pncp, nelems, buf);

    if (pncp->flag & NC_MODE_SAFE) /* put APIs are collective */
        err = check_consistency_put(pncp->comm, varid, name, xtype, nelems,
                                    buf, itype, err);
    if (err != NC_NOERR) return err;')

    /* calling the subroutine that implements APINAME($1,$2)() */
    return pncp->driver->`$1'_att(pncp->ncp, varid, name,
           ifelse(`$1',`put',`xtype, nelems,') buf, itype);
}
')dnl

foreach(`putget', (get, put),
        `foreach(`iType', (,text,schar,uchar,short,ushort,int,uint,long,float,double,longlong,ulonglong),
                 `GETPUT_ATT(putget, iType)
')')

