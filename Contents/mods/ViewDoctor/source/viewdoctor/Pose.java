package viewdoctor;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import org.lwjgl.util.vector.Matrix4f;

import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.Model;
import zombie.core.skinnedmodel.model.SkinningBone;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.iso.Vector3;

public final class Pose {
    private static final float BLEND_SECONDS = 0.35f;
    private static final float LOOK_RATE = 7f;
    private static final float ARM_METRES = 0.56f;
    private static final float LEG_METRES = 0.85f;
    private static final float HEAD_METRES = 1.55f;
    private static final float EYE_UP = 0.1f;
    private static final float EYE_AHEAD = 0.06f;
    private static final float MIN_PITCH = -1.45f;

    private static final String[][] PARTS = {
        { "Hand_L", "arm", "L", "L_Hand", "L_Finger1" },
        { "ForeArm_L", "arm", "L", "L_Forearm", "L_Hand" },
        { "UpperArm_L", "arm", "L", "L_UpperArm", "L_Forearm" },
        { "Hand_R", "arm", "R", "R_Hand", "R_Finger1" },
        { "ForeArm_R", "arm", "R", "R_Forearm", "R_Hand" },
        { "UpperArm_R", "arm", "R", "R_UpperArm", "R_Forearm" },
        { "Torso_Upper", "", "", "Spine1", "Neck" },
        { "Torso_Lower", "", "", "Spine", "Spine1" },
        { "Groin", "", "", "Pelvis", "Spine" },
        { "UpperLeg_L", "leg", "L", "L_Thigh", "L_Calf" },
        { "UpperLeg_R", "leg", "R", "R_Thigh", "R_Calf" },
        { "LowerLeg_L", "leg", "L", "L_Calf", "L_Foot" },
        { "LowerLeg_R", "leg", "R", "R_Calf", "R_Foot" },
        { "Foot_L", "leg", "L", "L_Foot", "L_Toe0" },
        { "Foot_R", "leg", "R", "R_Foot", "R_Toe0" },
    };

    private static final float[] K = {
        0.45f, 0.3f, -0.05f, 0.6f, 0.7f, 1f,
        0.45f, 0.3f, -0.05f, 0.6f, 0.7f, 1f,
        0.4f, 0.4f, -0.1f, 0.6f, 0.7f, 1f,
        1.35f, 0.75f, 0.03f,
        0.8f, -1f, -0.2f,
        0.16f,
    };

    static volatile boolean active;
    static volatile boolean broken;
    private static volatile String[] spec;
    private static volatile String freeSide = "";

    static volatile boolean seen;
    static volatile float screenX, screenY, screenAngle, screenLength;
    static volatile float screenAX, screenAY, screenBX, screenBY, screenWA, screenWB;

    static final float[] a = new float[3], b = new float[3];
    static final float[] frameX = new float[3], frameY = new float[3], frameZ = new float[3];
    static volatile float radius, length, unit = 1f;
    static volatile boolean flat, framed;
    public static volatile boolean lifting;
    static volatile String limbBone = "";
    static volatile Matrix4f limbMatrix;
    static final float[] handDir = new float[3];

    static volatile float toolX = 0.5f, toolY = 0.5f, cursorX = 0.5f, cursorY = 0.5f;
    static volatile boolean toolWanted, toolFree = true, cursorHit;

    static volatile float shownX, shownY;
    private static final float[] lastOrigin = new float[3], showAt = new float[3];
    private static volatile float lastTurn;
    private static float[] camera;
    private static final float[] ra = new float[3], rb = new float[3], ry = new float[3], rz = new float[3];
    private static volatile float rr;
    private static volatile boolean pickable;
    private static final float[] pickClip = new float[16], picked = new float[2];
    private static float handWeight;
    private static boolean handPlaced;
    private static final float[] handAt = new float[3], toolAt = new float[3];

    private static final String[] LIMB = { "Hand", "ForeArm", "UpperArm", "UpperLeg", "LowerLeg", "Foot", "Torso", "Groin" };
    private static final float[] RADIUS = { 0.045f, 0.04f, 0.05f, 0.08f, 0.06f, 0.05f, 0.15f, 0.12f };

    private static float weight;
    private static float restPitch = Float.NaN;
    private static long lastNanos;

    private static SkinningData bound;
    private static String[] boundSpec;
    private static String boundFree;
    private static int upper, fore, hand, toe, head, boneA, boneB, clavL, clavR, prop;
    private static int freeUpper, freeFore, freeHand, freeProp;
    private static int[] upperSet, foreSet, freeUpperSet, freeForeSet;
    private static Matrix4f[] models;

    private static final Vector3 across = new Vector3();
    private static final Vector3 along = new Vector3();
    private static final Matrix4f parentInverse = new Matrix4f();

    private static volatile int linked;
    private static Field viewOn, viewThird, lookYaw, lookPitch;
    private static Field viewProjection, frames, frameNumber, camX, camY, camZ, eyeX, eyeY, eyeZ;
    private static Method matrixGet;
    private static final float LEVEL = 2.4494896f;
    private static final float[] clip = new float[16];

    private Pose() {}

    public static String freeHand(String part, boolean leftUsable, boolean rightUsable) {
        boolean armPart = part.startsWith("Hand") || part.startsWith("ForeArm") || part.startsWith("UpperArm");
        if (armPart && part.endsWith("_L")) return rightUsable ? "R" : "";
        if (armPart && part.endsWith("_R")) return leftUsable ? "L" : "";
        return rightUsable ? "R" : leftUsable ? "L" : "";
    }

    static boolean start(String part, boolean leftUsable, boolean rightUsable) {
        if (broken) return false;
        for (String[] s : PARTS) {
            if (s[0].equals(part)) {
                freeSide = freeHand(part, leftUsable, rightUsable);
                spec = s;
                seen = false;
                pickable = false;
                framed = false;
                camera = null;
                handPlaced = false;
                handWeight = 0f;
                toolWanted = false;
                toolFree = true;
                cursorHit = false;
                if (weight <= 0f) restPitch = Float.NaN;
                active = true;
                return true;
            }
        }
        return false;
    }

    static void stop() {
        active = false;
        seen = false;
        pickable = false;
        toolWanted = false;
    }

    static void quit() {
        lifting = false;
        seen = false;
        pickable = false;
        framed = false;
        toolFree = true;
        Props.clear();
    }

    public static void posed(AnimationPlayer ap) {
        if (broken || ap == null) return;
        IsoPlayer p = IsoPlayer.players[0];
        if (p == null || ap.getIsoGameCharacter() != p) return;
        if (!active && weight <= 0f) return;
        try {
            run(p, ap);
        } catch (Throwable t) {
            broken = true;
            active = false;
            weight = 0f;
            quit();
            System.out.println("[ViewDoctor] pose failed and is now off, the minigames still work: " + t);
        }
    }

    private static void run(IsoPlayer p, AnimationPlayer ap) {
        long now = System.nanoTime();
        float dt = lastNanos == 0L ? 0f : Math.min(0.1f, (now - lastNanos) * 1e-9f);
        lastNanos = now;
        weight = active ? Math.min(1f, weight + dt / BLEND_SECONDS) : Math.max(0f, weight - dt / BLEND_SECONDS);
        if (!active && weight <= 0f) {
            lastNanos = 0L;
            quit();
            return;
        }
        String[] s = spec;
        if (s == null || !ap.isReady() || ap.isRagdolling() || p.isDead() || p.getVehicle() != null) {
            quit();
            return;
        }
        if (!bind(ap, s, freeSide)) {
            quit();
            return;
        }
        for (int i = 0; i < models.length; i++) models[i] = null;
        if (upper >= 0) {
            fill(ap, upperSet);
            fill(ap, foreSet);
        }
        if (freeUpper >= 0) {
            fill(ap, freeUpperSet);
            fill(ap, freeForeSet);
        }
        for (int i : new int[] { head, boneA, boneB, clavL, clavR }) models[i] = ap.getModelTransformAt(i);

        float[] f = facing(p, ap.getRenderedAngle());
        float[] fwd = { f[0], 0f, f[1] };
        float[] right = { -f[1], 0f, f[0] };
        if (dot(sub(pos(models[clavL]), pos(models[clavR])), right) > 0f) scale(right, -1f);
        float w = weight * weight * (3f - 2f * weight);

        float[] hd = pos(models[head]);
        float unit = Reach.dist(pos(models[clavL]), pos(models[clavR])) / 0.32f;
        Pose.unit = Math.max(0.05f, hd[1] / HEAD_METRES);
        float arm = 0f;
        if (upper >= 0) {
            float[] sh = pos(models[upper]), el = pos(models[fore]), hn = pos(models[hand]);
            arm = Reach.dist(sh, el) + Reach.dist(el, hn);
            if ("arm".equals(s[1])) unit = arm / ARM_METRES;
            Pose.unit = "arm".equals(s[1]) ? unit : arm / LEG_METRES;
        }
        float[] eye = eye(hd, fwd, unit);
        lifting = "leg".equals(s[1]) && firstPerson();
        if ("arm".equals(s[1])) raise(ap, s, eye, fwd, right, arm, w);
        else if (lifting) lift(ap, s, fwd, right, arm, w);
        limb(s, eye, Pose.unit);
        hold(ap, dt, w, fwd, right, eye);
        Props.place();

        try {
            Object frame = frame();
            if (frame == null) {
                seen = false;
                pickable = false;
                return;
            }
            float turn = ap.getRenderedAngle() + (float) Math.PI;
            float[] origin = { camX.getFloat(frame) - p.getX(), (p.getZ() - camZ.getFloat(frame)) * LEVEL, camY.getFloat(frame) - p.getY() };
            float[] view = { eyeX.getFloat(frame), eyeY.getFloat(frame), eyeZ.getFloat(frame) };
            for (int i = 0; i < 3; i++) lastOrigin[i] = origin[i];
            lastTurn = turn;
            float[] a = render(origin, turn, boneA), b = render(origin, turn, boneB);
            float[] target = { (a[0] + b[0]) / 2f, (a[1] + b[1]) / 2f, (a[2] + b[2]) / 2f };
            float[] d = sub(target, view);
            float want = clamp((float) Math.atan2(d[1], Math.hypot(d[0], d[2])), MIN_PITCH, 0.2f);
            if (restPitch != restPitch) restPitch = lookPitch.getFloat(null);
            if (active) look(p, dt, want, w);
            else ease(dt, restPitch);
            project(a, b, target, view, radius(s[0]));
            aim(a, b, turn);
        } catch (ReflectiveOperationException e) {
            linked = -1;
            seen = false;
            pickable = false;
        }
    }

    private static void lift(AnimationPlayer ap, String[] s, float[] fwd, float[] right, float leg, float w) {
        float out = "L".equals(s[2]) ? -1f : 1f;
        int k = s[0].startsWith("UpperLeg") ? 0 : s[0].startsWith("LowerLeg") ? 6 : 12;
        float[] hip = pos(models[upper]), foot = pos(models[hand]);
        float[] goal = { hip[0], hip[1] + K[k + 1] * leg, hip[2] };
        add(goal, fwd, K[k] * leg);
        add(goal, right, out * K[k + 2] * leg);
        for (int i = 0; i < 3; i++) goal[i] = foot[i] + (goal[i] - foot[i]) * w;
        float[] pole = { 0f, K[k + 4], 0f };
        add(pole, fwd, K[k + 3]);
        add(pole, right, out * K[k + 5]);
        Reach.arm(models, upperSet, foreSet, upper, fore, hand, toe, goal, pole);
        local(ap, upper);
        local(ap, fore);
    }

    private static void limb(String[] s, float[] eye, float unit) {
        Matrix4f m = models[boneA];
        float[] pa = pos(m), pb = pos(models[boneB]);
        for (int i = 0; i < 3; i++) {
            a[i] = pa[i];
            b[i] = pb[i];
        }
        flat = s[0].startsWith("Torso") || s[0].equals("Groin");
        radius = radius(s[0]) * K[18] * unit;
        length = Reach.dist(pa, pb);
        limbBone = "Bip01_" + s[3];
        limbMatrix = m;
        float[] from = camera != null ? camera : eye;
        float[] toward = { from[0] - (pa[0] + pb[0]) / 2f, from[1] - (pa[1] + pb[1]) / 2f, from[2] - (pa[2] + pb[2]) / 2f };
        framed = Reach.frame(a, b, toward, frameX, frameY, frameZ);
    }

    static void surface(float lx, float ly, float lift, float[] out) {
        if (flat) Reach.onPatch(a, b, frameY, radius * 2f, lx, ly, radius * K[19] + lift, frameZ, out);
        else Reach.onLimb(a, b, frameZ, frameY, radius, lx, ly, lift, out);
    }

    private static void hold(AnimationPlayer ap, float dt, float w, float[] fwd, float[] right, float[] eye) {
        boolean can = freeUpper >= 0 && toolWanted && framed;
        float[] hn = freeUpper >= 0 ? pos(models[freeHand]) : null;
        if (can) {
            surface(clamp(toolX, -0.3f, 1.3f), clamp(toolY, -0.3f, 1.3f), K[20] * unit, toolAt);
            float[] sh = pos(models[freeUpper]), el = pos(models[freeFore]);
            float[] back = Reach.aside(sub(sh, toolAt), sub(eye, toolAt), frameX);
            if (back != null) {
                for (int i = 0; i < 3; i++) {
                    handDir[i] = back[i];
                    toolAt[i] += back[i] * K[24] * unit;
                }
            }
            can = Reach.reaches(sh, Reach.dist(sh, el) + Reach.dist(el, hn), toolAt);
        }
        toolFree = !can;
        handWeight = can ? Math.min(1f, handWeight + dt * 6f) : Math.max(0f, handWeight - dt * 6f);
        if (freeUpper < 0 || handWeight <= 0.01f) {
            handPlaced = false;
            return;
        }
        if (can) {
            float k = handPlaced ? Math.min(1f, dt * 14f) : 1f;
            if (!handPlaced) for (int i = 0; i < 3; i++) handAt[i] = hn[i];
            handPlaced = true;
            for (int i = 0; i < 3; i++) handAt[i] += (toolAt[i] - handAt[i]) * k;
        }
        float blend = handWeight * w;
        float[] goal = { hn[0] + (handAt[0] - hn[0]) * blend, hn[1] + (handAt[1] - hn[1]) * blend, hn[2] + (handAt[2] - hn[2]) * blend };
        float side = "L".equals(freeSide) ? 1f : -1f;
        float[] pole = { -right[0] * side * K[21] + fwd[0] * K[23], K[22], -right[2] * side * K[21] + fwd[2] * K[23] };
        Reach.arm(models, freeUpperSet, freeForeSet, freeUpper, freeFore, freeHand, goal, pole);
        local(ap, freeUpper);
        local(ap, freeFore);
        if (freeProp >= 0) local(ap, freeProp);
    }

    private static void turned(float[] v, float turn, float[] out) {
        float c = (float) Math.cos(turn), s = (float) Math.sin(turn);
        out[0] = -(c * v[0] + s * v[2]);
        out[1] = v[1];
        out[2] = c * v[2] - s * v[0];
    }

    private static void aim(float[] renderA, float[] renderB, float turn) {
        if (!framed) {
            pickable = false;
            return;
        }
        turned(frameZ, turn, rz);
        turned(frameY, turn, ry);
        float off = flat ? radius * K[19] * 1.5f : 0f;
        for (int i = 0; i < 3; i++) {
            ra[i] = renderA[i] + rz[i] * off;
            rb[i] = renderB[i] + rz[i] * off;
        }
        rr = radius * 1.5f;
        pickable = true;
    }

    static boolean cursor(float mx, float my) {
        if (!pickable || linked != 1) {
            cursorHit = false;
            return false;
        }
        try {
            float[] c = pickClip;
            matrixGet.invoke(viewProjection.get(null), (Object) c);
            Core core = Core.getInstance();
            float nx = 2f * mx / core.getScreenWidth() - 1f, ny = 1f - 2f * my / core.getScreenHeight();
            float[] n1 = { c[0] - nx * c[3], c[4] - nx * c[7], c[8] - nx * c[11] };
            float[] n2 = { c[1] - ny * c[3], c[5] - ny * c[7], c[9] - ny * c[11] };
            float[] nw = { c[3], c[7], c[11] };
            float[] dir = Reach.cross(n1, n2);
            if (dot(dir, nw) < 0f) scale(dir, -1f);
            float[] from = Reach.unproject(c, nx, ny, 0.05f), eye = Reach.unproject(c, 0f, 0f, 0f);
            if (!Reach.normalize(dir) || from == null || eye == null) {
                cursorHit = false;
                return false;
            }
            camera = Reach.toModel(lastOrigin, lastTurn, eye);
            picked[0] = cursorX;
            picked[1] = cursorY;
            boolean hit = flat ? Reach.pickPatch(from, dir, ra, rb, rz, ry, rr * 2f, picked) : Reach.pick(from, dir, ra, rb, rz, ry, rr, picked);
            cursorX = picked[0];
            cursorY = picked[1];
            cursorHit = hit;
            return hit;
        } catch (ReflectiveOperationException e) {
            linked = -1;
            cursorHit = false;
            return false;
        }
    }

    static boolean show(float lx, float ly) {
        if (!pickable || linked != 1) return false;
        try {
            surface(lx, ly, 0f, showAt);
            float[] p = point(Reach.toRender(lastOrigin, lastTurn, showAt));
            if (p == null) return false;
            shownX = p[0];
            shownY = p[1];
            return true;
        } catch (ReflectiveOperationException e) {
            linked = -1;
            return false;
        }
    }

    static float span() {
        float u = unit;
        return u < 1e-4f ? length : length / u;
    }

    static boolean flatPart() {
        String[] s = spec;
        return s != null && s[1].isEmpty();
    }

    static float aspect() {
        float l = length;
        if (l < 1e-4f) return 1f;
        return (flat ? 2f * radius : Reach.ARC * radius) / l;
    }

    private static float[] render(float[] origin, float turn, int bone) {
        return Reach.toRender(origin, turn, pos(models[bone]));
    }

    private static Object frame() throws ReflectiveOperationException {
        if (!firstPerson()) return null;
        Object[] all = (Object[]) frames.get(null);
        Object best = null;
        long newest = Long.MIN_VALUE;
        for (Object f : all) {
            if (f == null) continue;
            long n = frameNumber.getLong(f);
            if (n > newest) {
                newest = n;
                best = f;
            }
        }
        return best;
    }

    private static float[] eye(float[] hd, float[] fwd, float unit) {
        return new float[] { hd[0] + fwd[0] * EYE_AHEAD * unit, hd[1] + EYE_UP * unit, hd[2] + fwd[2] * EYE_AHEAD * unit };
    }

    private static void raise(AnimationPlayer ap, String[] s, float[] eye, float[] fwd, float[] right, float arm, float w) {
        float side = "L".equals(s[2]) ? 1f : -1f;
        float[] goal = { eye[0] + fwd[0] * 0.7f * arm, eye[1] - 0.42f * arm, eye[2] + fwd[2] * 0.7f * arm };
        String part = s[0];
        if (part.startsWith("UpperArm")) {
            goal = new float[] { eye[0] + fwd[0] * 0.4f * arm, eye[1] - 0.62f * arm, eye[2] + fwd[2] * 0.4f * arm };
            add(goal, right, side * 0.3f * arm);
        } else {
            add(goal, right, side * 0.08f * arm);
        }
        float[] h = pos(models[hand]);
        for (int i = 0; i < 3; i++) goal[i] = h[i] + (goal[i] - h[i]) * w;
        float[] pole = { -right[0] * side * 0.8f - fwd[0] * 0.2f, -1f, -right[2] * side * 0.8f - fwd[2] * 0.2f };
        Reach.arm(models, upperSet, foreSet, upper, fore, hand, goal, pole);
        local(ap, upper);
        local(ap, fore);
        if (prop >= 0) local(ap, prop);
    }

    private static void ease(float dt, float to) throws ReflectiveOperationException {
        float now = lookPitch.getFloat(null);
        lookPitch.setFloat(null, now + (to - now) * Math.min(1f, dt * LOOK_RATE));
    }

    private static void look(IsoPlayer p, float dt, float want, float w) throws ReflectiveOperationException {
        float now = lookPitch.getFloat(null);
        lookPitch.setFloat(null, now + (want - now) * Math.min(1f, dt * LOOK_RATE) * w);
        lookYaw.setFloat(null, p.getDirectionAngleRadians());
    }

    private static float[] point(float[] at) throws ReflectiveOperationException {
        matrixGet.invoke(viewProjection.get(null), (Object) clip);
        float x = clip[0] * at[0] + clip[4] * at[1] + clip[8] * at[2] + clip[12];
        float y = clip[1] * at[0] + clip[5] * at[1] + clip[9] * at[2] + clip[13];
        float w = clip[3] * at[0] + clip[7] * at[1] + clip[11] * at[2] + clip[15];
        if (w < 1e-3f) return null;
        Core core = Core.getInstance();
        return new float[] { core.getScreenWidth() * (0.5f + 0.5f * x / w), core.getScreenHeight() * (0.5f - 0.5f * y / w) };
    }

    private static float radius(String part) {
        for (int i = 0; i < LIMB.length; i++) if (part.startsWith(LIMB[i])) return RADIUS[i];
        return 0.05f;
    }

    private static void project(float[] a, float[] b, float[] target, float[] view, float r) throws ReflectiveOperationException {
        float[] t = point(target), pa = point(a), pb = point(b);
        if (t == null || pa == null || pb == null) {
            seen = false;
            return;
        }
        screenX = t[0];
        screenY = t[1];
        screenAngle = (float) Math.atan2(pb[1] - pa[1], pb[0] - pa[0]);
        screenLength = (float) Math.hypot(pb[0] - pa[0], pb[1] - pa[1]);
        float[] o = Reach.side(a, b, view, r);
        float fallback = Reach.len(o) * screenLength / Math.max(1e-4f, Reach.dist(a, b));
        screenWA = width(a, pa, o, fallback);
        screenWB = width(b, pb, o, fallback);
        screenAX = pa[0];
        screenAY = pa[1];
        screenBX = pb[0];
        screenBY = pb[1];
        seen = true;
    }

    private static float width(float[] end, float[] onScreen, float[] o, float fallback) throws ReflectiveOperationException {
        float[] p = point(new float[] { end[0] + o[0], end[1] + o[1], end[2] + o[2] });
        if (p == null) return fallback;
        return (float) Math.hypot(p[0] - onScreen[0], p[1] - onScreen[1]);
    }

    private static void fill(AnimationPlayer ap, int[] set) {
        for (int i : set) models[i] = ap.getModelTransformAt(i);
    }

    private static void local(AnimationPlayer ap, int index) {
        SkinningBone bone = ap.getSkinningData().getBoneAt(index);
        if (bone.parent == null) return;
        Matrix4f.invert(ap.getModelTransformAt(bone.parent.index), parentInverse);
        ap.boneTransforms[index].mul(ap.getModelTransformAt(index), parentInverse);
    }

    private static float[] facing(IsoPlayer p, float rendered) {
        across.set(1f, 0f, 0f);
        Model.vectorToWorldCoords(0f, 0f, 0f, rendered, across);
        along.set(0f, 0f, 1f);
        Model.vectorToWorldCoords(0f, 0f, 0f, rendered, along);
        float fx = p.getForwardDirectionX(), fy = p.getForwardDirectionY();
        float x = fx * across.x + fy * across.y;
        float z = fx * along.x + fy * along.y;
        float l = (float) Math.hypot(x, z);
        if (l < 1e-6f) return new float[] { 0f, 1f };
        return new float[] { x / l, z / l };
    }

    private static boolean bind(AnimationPlayer ap, String[] s, String free) {
        SkinningData data = ap.getSkinningData();
        if (data == null) return false;
        if (data == bound && s == boundSpec && free.equals(boundFree)) return head >= 0;
        bound = data;
        boundSpec = s;
        boundFree = free;
        head = bone(ap, "Head");
        boneA = bone(ap, s[3]);
        boneB = bone(ap, s[4]);
        clavL = bone(ap, "L_Clavicle");
        clavR = bone(ap, "R_Clavicle");
        upper = fore = hand = toe = prop = -1;
        freeUpper = freeFore = freeHand = freeProp = -1;
        models = new Matrix4f[data.numBones()];
        if (head < 0 || boneA < 0 || boneB < 0 || clavL < 0 || clavR < 0) {
            head = -1;
            return false;
        }
        if (!s[1].isEmpty()) {
            boolean arm = "arm".equals(s[1]);
            upper = bone(ap, s[2] + (arm ? "_UpperArm" : "_Thigh"));
            fore = bone(ap, s[2] + (arm ? "_Forearm" : "_Calf"));
            hand = bone(ap, s[2] + (arm ? "_Hand" : "_Foot"));
            if (arm) prop = bone(ap, "R".equals(s[2]) ? "Prop1" : "Prop2");
            else toe = bone(ap, s[2] + "_Toe0");
            if (upper < 0 || fore < 0 || hand < 0) {
                head = -1;
                return false;
            }
            upperSet = below(data, upper, prop);
            foreSet = below(data, fore, prop);
        }
        if (!free.isEmpty()) {
            freeUpper = bone(ap, free + "_UpperArm");
            freeFore = bone(ap, free + "_Forearm");
            freeHand = bone(ap, free + "_Hand");
            freeProp = bone(ap, "R".equals(free) ? "Prop1" : "Prop2");
            if (freeUpper < 0 || freeFore < 0 || freeHand < 0) {
                freeUpper = freeFore = freeHand = freeProp = -1;
            } else {
                freeUpperSet = below(data, freeUpper, freeProp);
                freeForeSet = below(data, freeFore, freeProp);
            }
        }
        return true;
    }

    private static int bone(AnimationPlayer ap, String name) {
        return ap.getSkinningBoneIndex("Bip01_" + name, -1);
    }

    private static int[] below(SkinningData data, int root, int extra) {
        int[] out = new int[data.numBones()];
        int n = 0;
        for (int i = 0; i < out.length; i++) {
            for (SkinningBone b = data.getBoneAt(i); b != null; b = b.parent) {
                if (b.index == root) {
                    out[n++] = i;
                    break;
                }
            }
        }
        if (extra >= 0) out[n++] = extra;
        return java.util.Arrays.copyOf(out, n);
    }

    static boolean firstPerson() {
        if (linked == 0) link();
        if (linked < 0) return false;
        try {
            return viewOn.getBoolean(null) && !viewThird.getBoolean(null);
        } catch (ReflectiveOperationException e) {
            linked = -1;
            return false;
        }
    }

    private static synchronized void link() {
        if (linked != 0) return;
        try {
            Class<?> view = Class.forName("viewpoint.core.View");
            Class<?> look = Class.forName("viewpoint.input.Look");
            viewOn = view.getField("enabled");
            viewThird = view.getField("thirdPerson");
            lookYaw = look.getField("yaw");
            lookPitch = look.getField("pitch");
            frames = Class.forName("viewpoint.FP").getDeclaredField("frames");
            frames.setAccessible(true);
            Class<?> frame = Class.forName("viewpoint.core.Frame");
            frameNumber = frame.getField("number");
            camX = frame.getField("camX");
            camY = frame.getField("camY");
            camZ = frame.getField("camZ");
            eyeX = frame.getField("eyeX");
            eyeY = frame.getField("eyeY");
            eyeZ = frame.getField("eyeZ");
            viewProjection = Class.forName("viewpoint.SceneDrawer").getDeclaredField("viewProjection");
            viewProjection.setAccessible(true);
            matrixGet = viewProjection.getType().getMethod("get", float[].class);
            linked = 1;
        } catch (Throwable t) {
            linked = -1;
            System.out.println("[ViewDoctor] Viewpoint not found, the arm is raised but the camera is left alone: " + t);
        }
    }

    private static float[] pos(Matrix4f m) {
        return Reach.pos(m);
    }

    private static float[] sub(float[] a, float[] b) {
        return Reach.sub(a, b);
    }

    private static float dot(float[] a, float[] b) {
        return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    }

    private static void scale(float[] a, float k) {
        a[0] *= k;
        a[1] *= k;
        a[2] *= k;
    }

    private static void add(float[] a, float[] b, float k) {
        a[0] += b[0] * k;
        a[1] += b[1] * k;
        a[2] += b[2] * k;
    }

    private static float clamp(float v, float lo, float hi) {
        return Math.max(lo, Math.min(hi, v));
    }
}
