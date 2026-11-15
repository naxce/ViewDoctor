package viewdoctor;

import me.zed_0xff.zombie_buddy.Patch;

@Patch(className = "viewpoint.models.ModelCapture", methodName = "legs")
public class PatchLegs {
    @Patch.OnEnter(skipOn = true)
    public static boolean enter() {
        return Pose.lifting;
    }
}
