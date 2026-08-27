#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static id (*orig_classForElement)(id self, SEL _cmd, id element, id context);

static id hooked_classForElement(id self, SEL _cmd, id element, id context)
{
    id nodeClass = orig_classForElement(self, _cmd, element, context);

    if (nodeClass != nil) {
        Class commentNodeClass = objc_getClass("YTCommentNode");

        if (commentNodeClass != Nil &&
            nodeClass == (id)commentNodeClass) {

            NSLog(@"[YTCDT-Test] YTCommentNode blocked: %@", element);
            return nil;
        }
    }

    return nodeClass;
}

__attribute__((constructor))
static void init_tweak(void)
{
    Class cls = objc_getClass("ELMNodeFactory");

    if (cls == Nil) {
        NSLog(@"[YTCDT-Test] ELMNodeFactory not found");
        return;
    }

    SEL sel = sel_registerName(
        "classForElement:materializationContext:"
    );

    Method method = class_getInstanceMethod(cls, sel);

    if (method == NULL) {
        NSLog(@"[YTCDT-Test] classForElement:materializationContext: not found");
        return;
    }

    orig_classForElement =
        (id (*)(id, SEL, id, id))method_getImplementation(method);

    method_setImplementation(
        method,
        (IMP)hooked_classForElement
    );

    NSLog(@"[YTCDT-Test] Hook installed");
}