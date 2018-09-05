#include "./config.common"
#define SOLVER_TIME_ADAPTATION
#define SOLVER_TIME_ADAPTATION_METHOD AYMARD
#define SOLVER_TIME_ADAPTATION_FACTOR sqrt(2)
#define SOLVER_TIME_ADAPTATION_TOL_MAX 8e-2
#define SOLVER_TIME_ADAPTATION_TOL_MIN 4e-2
#define SOLVER_TIME_ADAPTATION_DT_OVER_PE_MIN 1e-8
#define SOLVER_TIME_ADAPTATION_DT_OVER_PE_MAX (SOLVER_DT/Pe)*SOLVER_TIME_ADAPTATION_FACTOR^32*0.99
