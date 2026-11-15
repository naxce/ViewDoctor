package viewdoctor;

import org.lwjgl.util.vector.Matrix4f;

public final class Reach {
    private static final Matrix4f turn = new Matrix4f();
    private static final Matrix4f probe = new Matrix4f();

    private Reach() {}

    public static void arm(Matrix4f[] models, int[] upperSet, int[] foreSet, int s, int e, int h, float[] target, float[] pole) {
        arm(models, upperSet, foreSet, s, e, h, -1, target, pole);
    }

    public static void arm(Matrix4f[] models, int[] upperSet, int[] foreSet, int s, int e, int h, int front, float[] target, float[] pole) {
        float[] sp = pos(models[s]), ep = pos(models[e]), hp = pos(models[h]);
        float a = dist(sp, ep), b = dist(ep, hp);
        float[] to = sub(target, sp);
        float d = len(to);
        if (a < 1e-5f || b < 1e-5f || d < 1e-5f) return;
        float[] u = { to[0] / d, to[1] / d, to[2] / d };
        d = clamp(d, Math.abs(a - b) + 1e-4f, a + b - 1e-4f);
        float cos = clamp((a * a + d * d - b * b) / (2 * a * d), -1f, 1f);
        float along = a * cos, out = a * (float) Math.sqrt(1 - cos * cos);
        float pu = pole[0] * u[0] + pole[1] * u[1] + pole[2] * u[2];
        float[] p = { pole[0] - pu * u[0], pole[1] - pu * u[1], pole[2] - pu * u[2] };
        if (!normalize(p)) return;
        float[] elbow = { sp[0] + u[0] * along + p[0] * out, sp[1] + u[1] * along + p[1] * out, sp[2] + u[2] * along + p[2] * out };
        float[] wrist = { sp[0] + u[0] * d, sp[1] + u[1] * d, sp[2] + u[2] * d };
        aim(models, upperSet, e, sp, elbow);
        if (front >= 0) hinge(models, upperSet, sp, pos(models[e]), pos(models[h]), pos(models[front]), wrist, h, front);
        aim(models, foreSet, h, pos(models[e]), wrist);
    }

    private static float[] across(float[] v, float[] axis) {
        float k = v[0] * axis[0] + v[1] * axis[1] + v[2] * axis[2];
        return new float[] { v[0] - k * axis[0], v[1] - k * axis[1], v[2] - k * axis[2] };
    }

    private static void hinge(Matrix4f[] models, int[] set, float[] sp, float[] ep, float[] hp, float[] fp, float[] wrist, int h, int front) {
        float[] axis = sub(ep, sp);
        if (!normalize(axis)) return;
        float[] back = across(sub(hp, fp), axis), want = across(sub(wrist, ep), axis);
        if (!normalize(back) || !normalize(want)) return;
        float[] c = cross(back, want);
        float angle = (float) Math.atan2(len(c), back[0] * want[0] + back[1] * want[1] + back[2] * want[2]);
        float best = -2f;
        float pick = 0f;
        for (float a : new float[] { angle, -angle }) {
            about(axis, sp, a, turn);
            Matrix4f.mul(models[h], turn, probe);
            float[] nh = pos(probe);
            Matrix4f.mul(models[front], turn, probe);
            float[] nb = across(sub(nh, pos(probe)), axis);
            if (!normalize(nb)) continue;
            float d = nb[0] * want[0] + nb[1] * want[1] + nb[2] * want[2];
            if (d > best) {
                best = d;
                pick = a;
            }
        }
        about(axis, sp, pick, turn);
        for (int i : set) Matrix4f.mul(models[i], turn, models[i]);
    }

    private static void aim(Matrix4f[] models, int[] set, int tip, float[] pivot, float[] goal) {
        float[] from = sub(pos(models[tip]), pivot), to = sub(goal, pivot);
        float[] axis = cross(from, to);
        if (!normalize(axis)) return;
        float angle = angle(from, to);
        about(axis, pivot, angle, turn);
        Matrix4f.mul(models[tip], turn, probe);
        float plus = dist(pos(probe), goal);
        about(axis, pivot, -angle, turn);
        Matrix4f.mul(models[tip], turn, probe);
        if (plus <= dist(pos(probe), goal)) about(axis, pivot, angle, turn);
        for (int i : set) Matrix4f.mul(models[i], turn, models[i]);
    }

    public static void about(float[] n, float[] p, float angle, Matrix4f m) {
        float x = n[0], y = n[1], z = n[2];
        float c = (float) Math.cos(angle), s = (float) Math.sin(angle), t = 1f - c;
        m.m00 = c + t * x * x;
        m.m01 = t * x * y - s * z;
        m.m02 = t * x * z + s * y;
        m.m10 = t * y * x + s * z;
        m.m11 = c + t * y * y;
        m.m12 = t * y * z - s * x;
        m.m20 = t * z * x - s * y;
        m.m21 = t * z * y + s * x;
        m.m22 = c + t * z * z;
        m.m30 = 0f;
        m.m31 = 0f;
        m.m32 = 0f;
        m.m33 = 1f;
        m.m03 = p[0] - (m.m00 * p[0] + m.m01 * p[1] + m.m02 * p[2]);
        m.m13 = p[1] - (m.m10 * p[0] + m.m11 * p[1] + m.m12 * p[2]);
        m.m23 = p[2] - (m.m20 * p[0] + m.m21 * p[1] + m.m22 * p[2]);
    }

    public static final float ARC = 2.4f;

    public static boolean frame(float[] a, float[] b, float[] toward, float[] outX, float[] outY, float[] outZ) {
        float x0 = b[0] - a[0], x1 = b[1] - a[1], x2 = b[2] - a[2];
        float l = (float) Math.sqrt(x0 * x0 + x1 * x1 + x2 * x2);
        if (l < 1e-6f) return false;
        x0 /= l;
        x1 /= l;
        x2 /= l;
        float t = toward[0] * x0 + toward[1] * x1 + toward[2] * x2;
        float z0 = toward[0] - t * x0, z1 = toward[1] - t * x1, z2 = toward[2] - t * x2;
        float zl = (float) Math.sqrt(z0 * z0 + z1 * z1 + z2 * z2);
        if (zl < 1e-5f * Math.max(1f, len(toward))) return false;
        z0 /= zl;
        z1 /= zl;
        z2 /= zl;
        outX[0] = x0;
        outX[1] = x1;
        outX[2] = x2;
        outZ[0] = z0;
        outZ[1] = z1;
        outZ[2] = z2;
        outY[0] = z1 * x2 - z2 * x1;
        outY[1] = z2 * x0 - z0 * x2;
        outY[2] = z0 * x1 - z1 * x0;
        return true;
    }

    public static float[] unproject(float[] c, float nx, float ny, float w) {
        float[] n1 = { c[0] - nx * c[3], c[4] - nx * c[7], c[8] - nx * c[11] };
        float[] n2 = { c[1] - ny * c[3], c[5] - ny * c[7], c[9] - ny * c[11] };
        float[] nw = { c[3], c[7], c[11] };
        float d1 = -(c[12] - nx * c[15]), d2 = -(c[13] - ny * c[15]), dw = w - c[15];
        float[] c23 = cross(n2, nw), c31 = cross(nw, n1), c12 = cross(n1, n2);
        float det = n1[0] * c23[0] + n1[1] * c23[1] + n1[2] * c23[2];
        if (Math.abs(det) < 1e-12f) return null;
        return new float[] {
            (d1 * c23[0] + d2 * c31[0] + dw * c12[0]) / det,
            (d1 * c23[1] + d2 * c31[1] + dw * c12[1]) / det,
            (d1 * c23[2] + d2 * c31[2] + dw * c12[2]) / det,
        };
    }

    public static float[] toRender(float[] origin, float turn, float[] m) {
        float c = (float) Math.cos(turn), s = (float) Math.sin(turn);
        return new float[] { origin[0] - 1.5f * (c * m[0] + s * m[2]), origin[1] + 1.5f * m[1], origin[2] + 1.5f * (c * m[2] - s * m[0]) };
    }

    public static float[] toModel(float[] origin, float turn, float[] r) {
        float c = (float) Math.cos(turn), s = (float) Math.sin(turn);
        float v0 = (r[0] - origin[0]) / 1.5f, v2 = (r[2] - origin[2]) / 1.5f;
        return new float[] { -c * v0 - s * v2, (r[1] - origin[1]) / 1.5f, c * v2 - s * v0 };
    }

    public static void onLimb(float[] a, float[] b, float[] z, float[] y, float r, float lx, float ly, float lift, float[] out) {
        float angle = (ly - 0.5f) * ARC;
        float c = (float) Math.cos(angle) * (r + lift), s = (float) Math.sin(angle) * (r + lift);
        for (int i = 0; i < 3; i++) out[i] = a[i] + (b[i] - a[i]) * lx + z[i] * c + y[i] * s;
    }

    public static void onPatch(float[] a, float[] b, float[] y, float width, float lx, float ly, float lift, float[] z, float[] out) {
        for (int i = 0; i < 3; i++) out[i] = a[i] + (b[i] - a[i]) * lx + y[i] * (ly - 0.5f) * width + z[i] * lift;
    }

    public static boolean pick(float[] eye, float[] dir, float[] a, float[] b, float[] z, float[] y, float r, float[] out) {
        out[0] = 0.5f;
        out[1] = 0.5f;
        float x0 = b[0] - a[0], x1 = b[1] - a[1], x2 = b[2] - a[2];
        float l = (float) Math.sqrt(x0 * x0 + x1 * x1 + x2 * x2);
        if (l < 1e-6f || r < 1e-6f) return false;
        x0 /= l;
        x1 /= l;
        x2 /= l;
        float e0 = eye[0] - a[0], e1 = eye[1] - a[1], e2 = eye[2] - a[2];
        float ex = e0 * x0 + e1 * x1 + e2 * x2;
        float ey = e0 * y[0] + e1 * y[1] + e2 * y[2];
        float ez = e0 * z[0] + e1 * z[1] + e2 * z[2];
        float dx = dir[0] * x0 + dir[1] * x1 + dir[2] * x2;
        float dy = dir[0] * y[0] + dir[1] * y[1] + dir[2] * y[2];
        float dz = dir[0] * z[0] + dir[1] * z[1] + dir[2] * z[2];
        float dd = dy * dy + dz * dz;
        float far = (float) Math.sqrt(ey * ey + ez * ez);
        if (dd < 1e-10f || far <= r) return false;
        float along = ey * dy + ez * dz;
        float disc = along * along - dd * (far * far - r * r);
        if (disc >= 0f) {
            float t = (-along - (float) Math.sqrt(disc)) / dd;
            if (t > 0f) {
                out[0] = (ex + t * dx) / l;
                out[1] = 0.5f + (float) Math.atan2(ey + t * dy, ez + t * dz) / ARC;
                return out[0] >= 0f && out[0] <= 1f;
            }
        }
        float t = Math.max(0f, -along / dd);
        float cy = ey + t * dy, cz = ez + t * dz;
        float near = (float) Math.sqrt(cy * cy + cz * cz);
        float from = (float) Math.atan2(ey, ez);
        float side = ey * cz - ez * cy >= 0f ? -1f : 1f;
        float rim = (float) Math.acos(clamp(r / far, -1f, 1f));
        out[0] = (ex + t * dx) / l;
        out[1] = 0.5f + (from + side * (rim + Math.max(0f, near - r) / r)) / ARC;
        return false;
    }

    public static boolean pickPatch(float[] eye, float[] dir, float[] a, float[] b, float[] z, float[] y, float width, float[] out) {
        float x0 = b[0] - a[0], x1 = b[1] - a[1], x2 = b[2] - a[2];
        float ll = x0 * x0 + x1 * x1 + x2 * x2;
        float facing = dir[0] * z[0] + dir[1] * z[1] + dir[2] * z[2];
        if (ll < 1e-12f || width < 1e-6f || Math.abs(facing) < 1e-6f) return false;
        float t = ((a[0] - eye[0]) * z[0] + (a[1] - eye[1]) * z[1] + (a[2] - eye[2]) * z[2]) / facing;
        if (t <= 0f) return false;
        float p0 = eye[0] + dir[0] * t - a[0], p1 = eye[1] + dir[1] * t - a[1], p2 = eye[2] + dir[2] * t - a[2];
        out[0] = (p0 * x0 + p1 * x1 + p2 * x2) / ll;
        out[1] = 0.5f + (p0 * y[0] + p1 * y[1] + p2 * y[2]) / width;
        return out[0] >= 0f && out[0] <= 1f && out[1] >= 0f && out[1] <= 1f;
    }

    public static float[] aside(float[] toShoulder, float[] toEye, float[] axis) {
        float[] view = toEye.clone();
        if (!normalize(view)) return null;
        float[] out = toShoulder.clone();
        float v = out[0] * view[0] + out[1] * view[1] + out[2] * view[2];
        float x = (out[0] * axis[0] + out[1] * axis[1] + out[2] * axis[2]) * 0.7f;
        for (int i = 0; i < 3; i++) out[i] -= view[i] * v + axis[i] * x;
        return normalize(out) ? out : null;
    }

    public static boolean reaches(float[] shoulder, float arm, float[] target) {
        return dist(shoulder, target) < arm * 0.98f;
    }

    public static float[] pos(Matrix4f m) {
        return new float[] { m.m03, m.m13, m.m23 };
    }

    public static float[] sub(float[] a, float[] b) {
        return new float[] { a[0] - b[0], a[1] - b[1], a[2] - b[2] };
    }

    public static float[] cross(float[] a, float[] b) {
        return new float[] { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
    }

    public static float[] side(float[] a, float[] b, float[] view, float r) {
        float[] mid = { (a[0] + b[0]) / 2f, (a[1] + b[1]) / 2f, (a[2] + b[2]) / 2f };
        float[] o = cross(sub(b, a), sub(view, mid));
        if (!normalize(o)) return new float[3];
        o[0] *= r;
        o[1] *= r;
        o[2] *= r;
        return o;
    }

    public static float len(float[] a) {
        return (float) Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    }

    public static float dist3(float[] a, float[] b) {
        return dist(a, b);
    }

    static float dist(float[] a, float[] b) {
        return len(sub(a, b));
    }

    public static boolean normalize(float[] a) {
        float l = len(a);
        if (l < 1e-6f) return false;
        a[0] /= l;
        a[1] /= l;
        a[2] /= l;
        return true;
    }

    static float angle(float[] a, float[] b) {
        float la = len(a), lb = len(b);
        if (la < 1e-6f || lb < 1e-6f) return 0f;
        return (float) Math.acos(clamp((a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) / (la * lb), -1f, 1f));
    }

    static float clamp(float v, float lo, float hi) {
        return Math.max(lo, Math.min(hi, v));
    }
}
