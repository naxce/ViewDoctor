package viewdoctor;

import me.zed_0xff.zombie_buddy.Exposer;

@Exposer.LuaClass(name = "ViewDoctorPose")
public final class PoseLua {
    private PoseLua() {}

    public static boolean start(String part, boolean leftUsable, boolean rightUsable) {
        return Pose.start(part, leftUsable, rightUsable);
    }

    public static boolean cursor(double mx, double my) {
        return Pose.cursor((float) mx, (float) my);
    }

    public static double lx() {
        return Pose.cursorX;
    }

    public static double ly() {
        return Pose.cursorY;
    }

    public static boolean show(double lx, double ly) {
        return Pose.show((float) lx, (float) ly);
    }

    public static double sx() {
        return Pose.shownX;
    }

    public static double sy() {
        return Pose.shownY;
    }

    public static double aspect() {
        return Pose.aspect();
    }

    public static double span() {
        return Pose.span();
    }

    public static void tool(double lx, double ly) {
        Pose.toolX = (float) lx;
        Pose.toolY = (float) ly;
        Pose.toolWanted = true;
    }

    public static void rest() {
        Pose.toolWanted = false;
    }

    public static boolean toolFree() {
        return Pose.toolFree;
    }

    public static void stop() {
        Pose.stop();
    }

    public static boolean firstPerson() {
        return Pose.firstPerson();
    }

    public static boolean seen() {
        return Pose.seen;
    }

    public static double x() {
        return Pose.screenX;
    }

    public static double y() {
        return Pose.screenY;
    }

    public static double angle() {
        return Pose.screenAngle;
    }

    public static double length() {
        return Pose.screenLength;
    }

    public static double ax() {
        return Pose.screenAX;
    }

    public static double ay() {
        return Pose.screenAY;
    }

    public static double bx() {
        return Pose.screenBX;
    }

    public static double by() {
        return Pose.screenBY;
    }

    public static double wa() {
        return Pose.screenWA;
    }

    public static double wb() {
        return Pose.screenWB;
    }

    public static boolean working() {
        return !Pose.broken;
    }
}
