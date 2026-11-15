package viewdoctor;

import java.util.HashMap;

import org.lwjgl.util.vector.Matrix4f;

import zombie.characters.IsoPlayer;
import zombie.core.skinnedmodel.ModelManager;
import zombie.core.skinnedmodel.model.ModelInstance;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.ModelAttachment;
import zombie.scripting.objects.ModelScript;

public final class Props {
    public static final int MAX = 96;
    private static final int TOOL = MAX;
    private static final String SPOT = "vd";

    public static final class Slots {
        public final boolean[] live = new boolean[MAX];
        public final String[] model = new String[MAX];
        public final float[] lx = new float[MAX], ly = new float[MAX], lift = new float[MAX];
        public final float[] turn = new float[MAX], tilt = new float[MAX], scale = new float[MAX];

        public int set(int id, String name, float x, float y, float up, float around, float lean, float size) {
            if (id < 0 || id >= MAX || name == null || name.isEmpty()) return 0;
            if (x != x || y != y || up != up || around != around || lean != lean || size != size) return 0;
            boolean fresh = !live[id] || !name.equals(model[id]);
            live[id] = true;
            model[id] = name;
            lx[id] = x;
            ly[id] = y;
            lift[id] = up;
            turn[id] = around;
            tilt[id] = lean;
            scale[id] = size;
            return fresh ? 2 : 1;
        }

        public boolean drop(int id) {
            if (id < 0 || id >= MAX || !live[id]) return false;
            live[id] = false;
            model[id] = null;
            return true;
        }

        public void close() {
            for (int i = 0; i < MAX; i++) {
                live[i] = false;
                model[i] = null;
            }
        }

        public int count() {
            int n = 0;
            for (boolean b : live) if (b) n++;
            return n;
        }
    }

    static volatile boolean broken;
    private static boolean on;
    private static final Slots slots = new Slots();
    private static final ModelInstance[] made = new ModelInstance[MAX + 1];
    private static final ModelScript[] own = new ModelScript[MAX + 1];
    private static final ModelAttachment[] spot = new ModelAttachment[MAX + 1];
    private static final HashMap<String, String[]> known = new HashMap<>();

    private static String toolModel = "";
    private static float toolX, toolY, toolTilt, toolScale = 1f;

    private static final float[] at = new float[3], e1 = new float[3], e2 = new float[3], e3 = new float[3];
    private static final float[] l1 = new float[3], l2 = new float[3], l3 = new float[3], turns = new float[3];

    private Props() {}

    public static void angles(float[] x, float[] y, float[] z, float[] out) {
        out[0] = (float) Math.toDegrees(Math.atan2(-z[1], z[2]));
        out[1] = (float) Math.toDegrees(Math.asin(Reach.clamp(z[0], -1f, 1f)));
        out[2] = (float) Math.toDegrees(Math.atan2(-y[0], x[0]));
    }

    static synchronized boolean open() {
        if (broken || Pose.broken || !Pose.active || Pose.flatPart() || !Pose.firstPerson()) return false;
        on = true;
        return true;
    }

    static synchronized boolean working() {
        return on && !broken;
    }

    static synchronized void set(int id, String model, float lx, float ly, float lift, float turn, float tilt, float scale) {
        if (!on) return;
        if (slots.set(id, model, lx, ly, lift, turn, tilt, scale) == 2) release(id);
    }

    static synchronized void tool(String model, float lx, float ly, float tilt, float scale) {
        if (!on || scale != scale) return;
        toolScale = scale;
        String name = model == null ? "" : model;
        if (!name.equals(toolModel)) release(TOOL);
        toolModel = name;
        toolX = lx;
        toolY = ly;
        toolTilt = tilt;
    }

    static synchronized void drop(int id) {
        if (slots.drop(id)) release(id);
    }

    static synchronized void clear() {
        if (!on && toolModel.isEmpty() && slots.count() == 0) return;
        on = false;
        slots.close();
        toolModel = "";
        for (int i = 0; i <= MAX; i++) release(i);
    }

    static synchronized void place() {
        if (!on || broken) return;
        try {
            ModelManager.ModelSlot slot = slot();
            if (slot == null || !Pose.framed) return;
            Matrix4f bone = Pose.limbMatrix;
            if (bone == null) return;
            for (int i = 0; i < MAX; i++) {
                if (!slots.live[i]) continue;
                if (!ready(slot, i, slots.model[i], Pose.limbBone)) continue;
                put(i, bone, slots.lx[i], slots.ly[i], slots.lift[i] * Pose.unit, slots.turn[i], slots.tilt[i]);
                made[i].scale = size(slots.model[i]) * slots.scale[i] * Pose.unit;
            }
            if (toolModel.isEmpty()) return;
            if (!ready(slot, TOOL, toolModel, Pose.limbBone)) return;
            float turn = 0f;
            if (!Pose.toolFree) {
                float angle = Pose.flat ? 0f : (toolY - 0.5f) * Reach.ARC;
                float cn = (float) Math.cos(angle), sn = (float) Math.sin(angle);
                float along = 0f, around = 0f;
                for (int k = 0; k < 3; k++) {
                    along += Pose.handDir[k] * Pose.frameX[k];
                    around += Pose.handDir[k] * (Pose.frameY[k] * cn - Pose.frameZ[k] * sn);
                }
                turn = (float) Math.atan2(around, along);
            }
            put(TOOL, bone, toolX, toolY, 0.002f * Pose.unit, turn, toolTilt);
            made[TOOL].scale = size(toolModel) * toolScale * Pose.unit;
        } catch (Throwable t) {
            fail(t);
        }
    }

    private static ModelManager.ModelSlot slot() {
        IsoPlayer p = IsoPlayer.players[0];
        if (p == null || p.legsSprite == null) return null;
        ModelManager.ModelSlot slot = p.legsSprite.modelSlot;
        if (slot == null || slot.model == null || slot.model.animPlayer == null) return null;
        return slot;
    }

    private static String[] look(String name) {
        String[] k = known.get(name);
        if (k != null) return k;
        int cut = name.indexOf('@');
        String mesh = cut < 0 ? name : name.substring(0, cut);
        String tex = cut < 0 ? name : name.substring(cut + 1);
        ModelScript script = ScriptManager.instance.getModelScript(mesh);
        if (script != null) {
            k = new String[] { script.getMeshName(), script.getTextureName(), script.getShaderName(), Float.toString(script.scale) };
        } else {
            k = new String[] { "ViewDoctor/" + mesh, "ViewDoctor/" + tex, null, "1" };
        }
        known.put(name, k);
        return k;
    }

    private static float size(String name) {
        return Float.parseFloat(look(name)[3]);
    }

    private static boolean ready(ModelManager.ModelSlot slot, int i, String name, String bone) {
        ModelInstance inst = made[i];
        if (inst != null && (inst.parent != slot.model || inst.modelScript != own[i])) {
            made[i] = null;
            inst = null;
        }
        if (inst == null) {
            String[] k = look(name);
            inst = ModelManager.instance.addStatic(slot, k[0], k[1], bone, k[2]);
            if (inst == null) throw new IllegalStateException("model " + name + " did not load");
            if (own[i] == null) {
                own[i] = new ModelScript();
                spot[i] = new ModelAttachment(SPOT);
                own[i].addAttachment(spot[i]);
            }
            inst.modelScript = own[i];
            inst.attachmentNameSelf = SPOT;
            made[i] = inst;
        }
        return true;
    }

    private static void put(int i, Matrix4f bone, float lx, float ly, float lift, float turn, float tilt) {
        Pose.surface(lx, ly, lift, at);
        float angle = Pose.flat ? 0f : (ly - 0.5f) * Reach.ARC;
        float cn = (float) Math.cos(angle), sn = (float) Math.sin(angle);
        float ct = (float) Math.cos(turn), st = (float) Math.sin(turn);
        float cl = (float) Math.cos(tilt), sl = (float) Math.sin(tilt);
        for (int k = 0; k < 3; k++) {
            float normal = Pose.frameZ[k] * cn + Pose.frameY[k] * sn;
            float around = Pose.frameY[k] * cn - Pose.frameZ[k] * sn;
            float flatX = Pose.frameX[k] * ct + around * st;
            e1[k] = flatX * cl + normal * sl;
            e2[k] = normal * cl - flatX * sl;
        }
        e3[0] = e1[1] * e2[2] - e1[2] * e2[1];
        e3[1] = e1[2] * e2[0] - e1[0] * e2[2];
        e3[2] = e1[0] * e2[1] - e1[1] * e2[0];
        float px = at[0] - bone.m03, py = at[1] - bone.m13, pz = at[2] - bone.m23;
        spot[i].getOffset().set(
            bone.m00 * px + bone.m10 * py + bone.m20 * pz,
            bone.m01 * px + bone.m11 * py + bone.m21 * pz,
            bone.m02 * px + bone.m12 * py + bone.m22 * pz);
        local(bone, e1, l1);
        local(bone, e2, l2);
        local(bone, e3, l3);
        angles(l1, l2, l3, turns);
        spot[i].getRotate().set(turns[0], turns[1], turns[2]);
    }

    private static void local(Matrix4f bone, float[] v, float[] out) {
        out[0] = bone.m00 * v[0] + bone.m10 * v[1] + bone.m20 * v[2];
        out[1] = bone.m01 * v[0] + bone.m11 * v[1] + bone.m21 * v[2];
        out[2] = bone.m02 * v[0] + bone.m12 * v[1] + bone.m22 * v[2];
    }

    private static void release(int i) {
        ModelInstance inst = made[i];
        made[i] = null;
        if (inst == null) return;
        try {
            ModelManager.ModelSlot slot = slot();
            if (slot == null || inst.parent != slot.model || inst.modelScript != own[i]) return;
            slot.sub.remove(inst);
            slot.model.sub.remove(inst);
            ModelManager.instance.resetModelInstanceRecurse(inst, slot);
        } catch (Throwable t) {
            if (!broken) fail(t);
        }
    }

    private static void fail(Throwable t) {
        broken = true;
        on = false;
        slots.close();
        toolModel = "";
        for (int i = 0; i <= MAX; i++) {
            ModelInstance inst = made[i];
            made[i] = null;
            if (inst == null) continue;
            try {
                ModelManager.ModelSlot slot = slot();
                if (slot != null && inst.parent == slot.model && inst.modelScript == own[i]) {
                    slot.sub.remove(inst);
                    slot.model.sub.remove(inst);
                    ModelManager.instance.resetModelInstanceRecurse(inst, slot);
                }
            } catch (Throwable ignored) {
                made[i] = null;
            }
        }
        System.out.println("[ViewDoctor] props failed and are now off, the minigames still work: " + t);
    }
}
