package viewdoctor;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.core.skinnedmodel.animation.AnimationPlayer;

@Patch(className = "zombie.core.skinnedmodel.animation.AnimationPlayer", methodName = "updateModelTransforms")
public class PatchPosed {
    @Patch.OnExit
    public static void exit(@Patch.This AnimationPlayer ap) {
        Pose.posed(ap);
    }
}
