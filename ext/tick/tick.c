#include "ruby.h"

static VALUE rb_cTick;

void Init_tick()
{
    rb_cTick = rb_define_class("Tick", rb_cObject);
}
