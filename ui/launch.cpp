#include "launch.h"

Launch *Launch::instance()
{
    static Launch *l = new Launch();
    return l;
}
