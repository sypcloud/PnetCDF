/* -*- Mode: C; c-basic-offset:4 ; -*- */
/*  
 *  (C) 2001 by Argonne National Laboratory.
 *      See COPYRIGHT in top-level directory.
 *
 * This file is automatically generated by buildiface -infile=../lib/pnetcdf.h -deffile=defs
 * DO NOT EDIT
 */
#include "mpinetcdf_impl.h"


#ifdef F77_NAME_UPPER
#define nfmpi_get_vars_ NFMPI_GET_VARS
#elif defined(F77_NAME_LOWER_2USCORE)
#define nfmpi_get_vars_ nfmpi_get_vars__
#elif !defined(F77_NAME_LOWER_USCORE)
#define nfmpi_get_vars_ nfmpi_get_vars
/* Else leave name alone */
#endif


/* Prototypes for the Fortran interfaces */
#include "mpifnetcdf.h"
FORTRAN_API void FORT_CALL nfmpi_get_vars_ ( int *v1, int *v2, int v3[], int v4[], int v5[], void*v6, int *v7, MPI_Fint *v8, MPI_Fint *ierr ){
    size_t *l3 = 0;
    size_t *l4 = 0;
    size_t *l5 = 0;

    { int ln = ncxVardim(*v1,*v2);
    if (ln > 0) {
        int li;
        l3 = (size_t *)malloc( ln * sizeof(size_t) );
        for (li=0; li<ln; li++) 
            l3[li] = v3[ln-1-li] - 1;
    }}

    { int ln = ncxVardim(*v1,*v2);
    if (ln > 0) {
        int li;
        l4 = (size_t *)malloc( ln * sizeof(size_t) );
        for (li=0; li<ln; li++) 
            l4[li] = v4[ln-1-li] - 1;
    }}

    { int ln = ncxVardim(*v1,*v2);
    if (ln > 0) {
        int li;
        l5 = (size_t *)malloc( ln * sizeof(size_t) );
        for (li=0; li<ln; li++) 
            l5[li] = v5[ln-1-li] - 1;
    }}
    *ierr = ncmpi_get_vars( *v1, *v2, l3, l4, l5, v6, *v7, (MPI_Datatype)(*v8) );

    if (l3) { free(l3); }

    if (l4) { free(l4); }

    if (l5) { free(l5); }
}
