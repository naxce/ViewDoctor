package viewdoctor;

import me.zed_0xff.zombie_buddy.Exposer;

@Exposer.LuaClass(name = "ViewDoctorProps")
public final class PropsLua {
    private PropsLua() {}

    public static boolean open() {
        return Props.open();
    }

    public static void set(int id, String model, double lx, double ly, double lift, double turn, double tilt, double scale) {
        Props.set(id, model, (float) lx, (float) ly, (float) lift, (float) turn, (float) tilt, (float) scale);
    }

    public static void tool(String model, double lx, double ly, double tilt, double scale) {
        Props.tool(model, (float) lx, (float) ly, (float) tilt, (float) scale);
    }

    public static void drop(int id) {
        Props.drop(id);
    }

    public static void close() {
        Props.clear();
    }

    public static boolean working() {
        return Props.working();
    }
}
