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
#define nfmpi_def_var_ NFMPI_DEF_VAR
#elif defined(F77_NAME_LOWER_2USCORE)
#define nfmpi_def_var_ nfmpi_def_var__
#elif !defined(F77_NAME_LOWER_USCORE)
#define nfmpi_def_var_ nfmpi_def_var
/* Else leave name alone */
#endif


/* Prototypes for the Fortran interfaces */
#include "mpifnetcdf.h"
FORTRAN_API void FORT_CALL nfmpi_def_var_ ( int *v1, char *v2 FORT_MIXED_LEN(d2), int *v3, int *v4, MPI_Fint *v5, MPI_Fint *v6, MPI_Fint *ierr FORT_END_LEN(d2) ){
    char *p2;
    int *l5=0;

    {char *p = v2 + d2 - 1;
     int  li;
        while (*p == ' ' && p > v2) p--;
        p++;
        p2 = (char *)malloc( p-v2 + 1 );
        for (li=0; li<(p-v2); li++) { p2[li] = v2[li]; }
        p2[li] = 0; 
    }

    { int ln = *v4;
    if (ln > 0) {
        int li;
        l5 = (size_t *)malloc( ln * sizeof(int) );
        for (li=0; li<ln; li++) 
            l5[li] = v5[ln-1-li] - 1;
    }}
    *ierr = ncmpi_def_var( *v1, p2, *v3, *v4, l5, v6 );
    free( p2 );

    if (l5) { free(l5); }
}
