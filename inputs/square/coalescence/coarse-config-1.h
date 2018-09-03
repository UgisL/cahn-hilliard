#include "./config.common"

// Time adatpation
#if SOLVER_TIME_ADAPTATION_METHOD == AYMARD
#define SOLVER_TIME_ADAPTATION_TOL_MIN 1e-3
#define SOLVER_TIME_ADAPTATION_TOL_MAX 2e-3
#endif

// Mesh adaptation
#define SOLVER_CN 0.01
#define SOLVER_MESH_ADAPTATION_HMIN 0.001
#define SOLVER_MESH_ADAPTATION_HMAX 0.05
