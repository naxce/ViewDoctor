import org.lwjgl.util.vector.Matrix4f;
import viewdoctor.Reach;

public class ReachTest {
    static Matrix4f at(float x, float y, float z) {
        Matrix4f m = new Matrix4f();
        m.setIdentity();
        m.m03 = x;
        m.m13 = y;
        m.m23 = z;
        return m;
    }

    static void check(boolean ok, String what) {
        if (!ok) throw new AssertionError(what);
    }

    static void reaches(float[] s, float[] e, float[] h, float[] target, String what) {
        Matrix4f[] models = { at(s[0], s[1], s[2]), at(e[0], e[1], e[2]), at(h[0], h[1], h[2]) };
        float a = Reach.dist3(s, e), b = Reach.dist3(e, h);
        float[] pole = { 0, -1, 0 };
        Reach.arm(models, new int[] { 0, 1, 2 }, new int[] { 1, 2 }, 0, 1, 2, target, pole);
        float[] sp = Reach.pos(models[0]), ep = Reach.pos(models[1]), hp = Reach.pos(models[2]);
        float mid = (sp[1] + target[1]) / 2f;
        check(ep[1] <= mid + 1e-3f, what + ": elbow hangs toward the pole");
        check(Reach.dist3(sp, s) < 1e-4f, what + ": shoulder stays put");
        check(Math.abs(Reach.dist3(sp, ep) - a) < 1e-3f && Math.abs(Reach.dist3(ep, hp) - b) < 1e-3f, what + ": bone lengths kept");
        check(Reach.dist3(hp, target) < 1e-3f, what + ": hand on target, off by " + Reach.dist3(hp, target));
    }

    static float dot(float[] a, float[] b) {
        return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    }

    static float[] norm(float[] to, float[] from) {
        float[] d = { to[0] - from[0], to[1] - from[1], to[2] - from[2] };
        float l = Reach.len(d);
        return new float[] { d[0] / l, d[1] / l, d[2] / l };
    }

    public static void main(String[] args) {
        Matrix4f m = at(1, 0, 0);
        Matrix4f t = new Matrix4f();
        Reach.about(new float[] { 0, 1, 0 }, new float[] { 0.5f, 0, 0 }, (float) Math.PI, t);
        Matrix4f.mul(m, t, m);
        float[] p = Reach.pos(m);
        check(Math.abs(p[0]) < 1e-4f && Math.abs(p[2]) < 1e-4f, "half turn about a pivot");

        float[] s = { 0.2f, 1.4f, 0 }, e = { 0.25f, 1.1f, 0 }, h = { 0.3f, 0.8f, 0 };
        reaches(s, e, h, new float[] { 0.05f, 1.55f, 0.35f }, "straight arm raised to the face");
        reaches(s, new float[] { 0.25f, 1.15f, 0.1f }, new float[] { 0.2f, 1.3f, 0.3f }, new float[] { -0.1f, 1.5f, 0.3f }, "bent arm crossing the body");
        reaches(s, e, h, new float[] { 0.2f, 1.3f, 0.25f }, "close target bends the elbow");
        float[] first = new float[3];
        for (int k = 0; k < 2; k++) {
            Matrix4f[] models = { at(s[0], s[1], s[2]), at(e[0], e[1], e[2]), at(h[0], h[1], h[2]) };
            for (int n = 0; n < 3; n++) Reach.arm(models, new int[] { 0, 1, 2 }, new int[] { 1, 2 }, 0, 1, 2, new float[] { 0.05f, 1.35f, 0.3f }, new float[] { 0, -1, 0 });
            float[] ep = Reach.pos(models[1]);
            if (k == 0) first = ep;
            else check(Reach.dist3(first, ep) < 1e-4f, "same target, same elbow every time");
        }
        float[] o = Reach.side(new float[] {0,0,0}, new float[] {1,0,0}, new float[] {0.5f,0,5}, 0.1f);
        float[] aside = Reach.aside(new float[] { 0.1f, 0.9f, 0.3f }, new float[] { 0f, 1f, 0f }, new float[] { 1f, 0f, 0f });
        check(aside != null && Math.abs(aside[1]) < 1e-5f, "the free hand keeps off the line of sight");
        check(Math.abs(aside[0]) < Math.abs(aside[2]), "the free hand comes from across the limb, not along it");
        check(Reach.aside(new float[] { 0f, 1f, 0f }, new float[] { 0f, 2f, 0f }, new float[] { 1f, 0f, 0f }) == null, "a shoulder on the line of sight gives no side");
        check(Math.abs(Reach.len(o) - 0.1f) < 1e-5f, "side offset has the limb radius");
        check(Math.abs(o[0]) < 1e-5f && Math.abs(o[2]) < 1e-5f, "side offset is across the limb and the view");
        float[] z = Reach.side(new float[] {0,0,0}, new float[] {0,0,1}, new float[] {0,0,5}, 0.1f);
        check(Reach.len(z) == 0f, "limb pointing at the eye has no side");
        float[] ca = { 0.1f, 1.0f, 0.2f }, cb = { 0.35f, 1.1f, 0.25f };
        float[] fx = new float[3], fy = new float[3], fz = new float[3];
        check(Reach.frame(ca, cb, new float[] { 0.2f, 0.3f, 1f }, fx, fy, fz), "frame of a real limb");
        check(Math.abs(dot(fx, fy)) < 1e-5f && Math.abs(dot(fx, fz)) < 1e-5f && Math.abs(dot(fy, fz)) < 1e-5f, "frame is orthogonal");
        check(Math.abs(Reach.len(fz) - 1f) < 1e-5f && dot(fz, new float[] { 0.2f, 0.3f, 1f }) > 0f, "z is the side facing the camera");
        check(!Reach.frame(ca, ca, fz, fx, fy, fz) && !Reach.frame(ca, cb, new float[] { 0.25f, 0.1f, 0.05f }, fx, fy, new float[3]), "degenerate frames are refused");
        Reach.frame(ca, cb, new float[] { 0.2f, 0.3f, 1f }, fx, fy, fz);
        float r = 0.05f;
        float[] mid = { (ca[0] + cb[0]) / 2f, (ca[1] + cb[1]) / 2f, (ca[2] + cb[2]) / 2f };
        float[] eye = { mid[0] + fz[0] * 0.5f, mid[1] + fz[1] * 0.5f, mid[2] + fz[2] * 0.5f };
        float[] at = new float[3], got = new float[2];
        for (float lx = 0.1f; lx < 0.95f; lx += 0.2f) {
            for (float ly = 0.1f; ly < 0.95f; ly += 0.1f) {
                Reach.onLimb(ca, cb, fz, fy, r, lx, ly, 0f, at);
                check(Reach.pick(eye, norm(at, eye), ca, cb, fz, fy, r, got), "ray at the limb hits it " + lx + " " + ly);
                check(Math.abs(got[0] - lx) < 1e-4f && Math.abs(got[1] - ly) < 1e-4f, "round trip " + lx + "," + ly + " gave " + got[0] + "," + got[1]);
            }
        }
        Reach.onLimb(ca, cb, fz, fy, r, 0.5f, 0.5f, 0.03f, at);
        check(Math.abs(Reach.dist3(at, mid) - 0.08f) < 1e-5f, "lift adds to the radius");
        float last = 0f;
        for (int side = -1; side <= 1; side += 2) {
            last = 0f;
            for (float d = 2f; d < 6.5f; d += 1f) {
                float[] past = { mid[0] + fy[0] * r * d * side, mid[1] + fy[1] * r * d * side, mid[2] + fy[2] * r * d * side };
                check(!Reach.pick(eye, norm(past, eye), ca, cb, fz, fy, r, got), "a ray passing beside the limb misses");
                check(side > 0 ? got[1] > 1f : got[1] < 0f, "a miss lands outside on the side it passed, got " + got[1]);
                check(Math.abs(got[1] - 0.5f) > last, "further out is further out");
                check(Math.abs(got[0] - 0.5f) < 0.05f, "a miss keeps its place along the limb, got " + got[0]);
                last = Math.abs(got[1] - 0.5f);
            }
        }
        Reach.onLimb(ca, cb, fz, fy, r, 0.5f, 0.5f + 0.6f, 0f, at);
        float[] graze = norm(at, eye);
        Reach.pick(eye, graze, ca, cb, fz, fy, r, got);
        float edge = got[1];
        float[] out2 = { mid[0] + fy[0] * r * 1.02f, mid[1] + fy[1] * r * 1.02f, mid[2] + fy[2] * r * 1.02f };
        Reach.pick(eye, norm(out2, eye), ca, cb, fz, fy, r, got);
        check(got[1] > edge && got[1] - edge < 0.2f, "the miss continues from the rim without a jump: " + edge + " then " + got[1]);
        check(!Reach.pick(eye, new float[] { 0, 1, 0 }, ca, ca, fz, fy, r, got) && got[0] == got[0] && got[1] == got[1], "degenerate axis: no hit, no NaN");
        check(!Reach.pick(eye, fx, ca, cb, fz, fy, r, got) && got[0] == got[0] && got[1] == got[1], "ray along the limb: no hit, no NaN");
        Reach.onLimb(ca, cb, fz, fy, r, 0.5f, 0.5f, 0f, at);
        float[] away = norm(eye, at);
        check(!Reach.pick(eye, away, ca, cb, fz, fy, r, got), "a ray pointing away from the limb misses");
        for (float lx = 0.1f; lx < 0.95f; lx += 0.2f) {
            for (float ly = 0.1f; ly < 0.95f; ly += 0.2f) {
                Reach.onPatch(ca, cb, fy, 0.3f, lx, ly, 0f, fz, at);
                check(Reach.pickPatch(eye, norm(at, eye), ca, cb, fz, fy, 0.3f, got), "ray at the patch hits it");
                check(Math.abs(got[0] - lx) < 1e-4f && Math.abs(got[1] - ly) < 1e-4f, "patch round trip " + lx + "," + ly);
            }
        }
        Reach.onPatch(ca, cb, fy, 0.3f, 0.5f, 1.4f, 0f, fz, at);
        check(!Reach.pickPatch(eye, norm(at, eye), ca, cb, fz, fy, 0.3f, got) && Math.abs(got[1] - 1.4f) < 1e-4f, "off the patch continues outward");
        check(!Reach.pickPatch(eye, fy, ca, cb, fz, fy, 0.3f, got) && got[1] == got[1], "ray along the patch: no hit, no NaN");
        check(viewdoctor.Pose.freeHand("ForeArm_L", true, true).equals("R"), "left arm wound: right hand works");
        check(viewdoctor.Pose.freeHand("ForeArm_L", true, false).equals(""), "left arm wound, no right hand: nobody holds the tool");
        check(viewdoctor.Pose.freeHand("Hand_R", true, true).equals("L"), "right hand wound: left hand works");
        check(viewdoctor.Pose.freeHand("UpperLeg_L", true, true).equals("R"), "leg wound: right hand works");
        check(viewdoctor.Pose.freeHand("UpperLeg_L", true, false).equals("L"), "leg wound, no right hand: left hand works");
        check(viewdoctor.Pose.freeHand("Torso_Upper", false, false).equals(""), "no hands: nobody holds the tool");
        float[] shoulder = { 0.2f, 1.4f, 0f };
        check(Reach.reaches(shoulder, 0.56f, new float[] { 0.2f, 1.0f, 0.2f }), "a target inside arm's length is reachable");
        check(!Reach.reaches(shoulder, 0.56f, new float[] { 0.2f, 0.8f, 0.2f }), "a target beyond upper plus fore length is unreachable");
        viewdoctor.Props.Slots slots = new viewdoctor.Props.Slots();
        check(slots.set(3, "VD_Dot", 0.2f, 0.5f, 0f, 0f, 0f, 1f) == 2, "a new prop needs a model");
        check(slots.set(3, "VD_Dot", 0.3f, 0.5f, 0f, 0f, 0f, 1f) == 1 && slots.lx[3] == 0.3f, "the same prop only moves");
        check(slots.set(3, "VD_Stitch", 0.3f, 0.5f, 0f, 0f, 0f, 1f) == 2 && slots.count() == 1, "another model replaces it in place");
        check(slots.set(4, "VD_Dot", 0.4f, 0.5f, 0f, 0f, 0f, 1f) == 2 && slots.count() == 2, "second prop");
        check(slots.set(96, "VD_Dot", 0.4f, 0.5f, 0f, 0f, 0f, 1f) == 0 && slots.set(-1, "VD_Dot", 0f, 0f, 0f, 0f, 0f, 1f) == 0 && slots.count() == 2, "ids outside the pool are ignored");
        check(slots.set(5, "", 0.4f, 0.5f, 0f, 0f, 0f, 1f) == 0 && slots.set(5, "VD_Dot", Float.NaN, 0.5f, 0f, 0f, 0f, 1f) == 0 && slots.count() == 2, "no model or a NaN place is ignored");
        check(slots.drop(3) && !slots.drop(3) && !slots.drop(96) && slots.count() == 1, "drop removes once");
        slots.close();
        slots.close();
        check(slots.count() == 0 && !slots.live[4], "close empties the pool and can be repeated");
        float[] turns = new float[3];
        viewdoctor.Props.angles(new float[] { 1, 0, 0 }, new float[] { 0, 1, 0 }, new float[] { 0, 0, 1 }, turns);
        check(Math.abs(turns[0]) + Math.abs(turns[1]) + Math.abs(turns[2]) < 1e-5f, "identity has no rotation");
        float ca2 = (float) Math.cos(0.4), sa2 = (float) Math.sin(0.4);
        viewdoctor.Props.angles(new float[] { ca2, sa2, 0 }, new float[] { -sa2, ca2, 0 }, new float[] { 0, 0, 1 }, turns);
        check(Math.abs(turns[0]) < 1e-5f && Math.abs(turns[1]) < 1e-5f && Math.abs(turns[2] - Math.toDegrees(0.4)) < 1e-3f, "a turn about z comes out as the z angle in degrees");
        viewdoctor.Props.angles(new float[] { 1, 0, 0 }, new float[] { 0, ca2, sa2 }, new float[] { 0, -sa2, ca2 }, turns);
        check(Math.abs(turns[0] - Math.toDegrees(0.4)) < 1e-3f && Math.abs(turns[1]) < 1e-5f && Math.abs(turns[2]) < 1e-5f, "a turn about x comes out as the x angle");
        float[] origin = { 3f, -1f, 2f }, model = { 0.2f, 0.7f, -0.4f };
        float[] back = Reach.toModel(origin, 1.1f, Reach.toRender(origin, 1.1f, model));
        check(Reach.dist3(back, model) < 1e-5f, "a point taken to the render and back lands where it started");
        float[] clip = new float[16];
        clip[0] = 1f;
        clip[5] = 1f;
        clip[11] = -1f;
        clip[12] = -0.3f;
        clip[13] = 0.8f;
        clip[15] = 2f;
        float[] start = Reach.unproject(clip, 0f, 0f, 0f);
        check(start != null && Reach.dist3(start, new float[] { 0.3f, -0.8f, 2f }) < 1e-5f, "the eye is where every ray of the view starts");
        Matrix4f[] leg = { at(0, 0, 0), at(0, -1, 0), at(0, -2, 0), at(0, -2, 0.3f) };
        Reach.arm(leg, new int[] { 0, 1, 2, 3 }, new int[] { 1, 2, 3 }, 0, 1, 2, 3, new float[] { 0.9f, -0.2f, 0.9f }, new float[] { 1, 0.5f, 0 });
        float[] hip = Reach.pos(leg[0]), knee = Reach.pos(leg[1]), ankle = Reach.pos(leg[2]), toes = Reach.pos(leg[3]);
        float[] thigh = Reach.sub(knee, hip), shin = Reach.sub(ankle, knee), foot = Reach.sub(toes, ankle);
        float[] plane = Reach.cross(thigh, shin);
        Reach.normalize(plane);
        Reach.normalize(foot);
        float side = plane[0] * foot[0] + plane[1] * foot[1] + plane[2] * foot[2];
        check(Math.abs(side) < 1e-3f, "the knee bends in the leg's own plane, the foot is off it by " + side);
        check(foot[0] * thigh[0] + foot[1] * thigh[1] + foot[2] * thigh[2] > 0f, "the toes point away from the hip, not back at the body");
        System.out.println("reach ok");
    }
}
