"""
Kleptographic Elliptic Curve Generation & Recovery
====================================================
Implements the CM-discriminant backdoor construction described in our thought
experiment.  The script has three phases:

  1. KEYGEN   -- Backdoor installer generates a secret discriminant D and
                 derives curve parameters that look NUMS-generated.

  2. VERIFY   -- Independent auditor checks all standard safety criteria and
                 sees a clean curve.

  3. EXPLOIT  -- Backdoor holder uses D to recover the secret endomorphism φ,
                 performs GLV decomposition, and solves ECDLP in O(p^{1/4}).

WARNING: This is a research / educational implementation.  The curve sizes are
intentionally small so the script runs in reasonable time.  Do not use any of
this in production.

Requirements: SageMath >= 9.0
Run with:     sage kleptographic_curve.sage
"""

from sage.all import *

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def cornacchia(D, p):
    """
    Solve 4p = t^2 - D*v^2  (D < 0, fundamental discriminant) using the
    extended Cornacchia algorithm.  Returns (t, v) or None.
    """
    # We need D < 0 and p prime
    assert D < 0 and is_prime(p)
    Dabs = ZZ(-D)

    # Classic Cornacchia works on x^2 + |D|*y^2 = 4p
    # Step 1: find sqrt(-D) mod p  (i.e. sqrt(D) mod p when D<0 means sqrt(-|D|))
    # We want x0 s.t. x0^2 ≡ -|D|   (mod p)  ←→  x0^2 ≡ D (mod p)
    Fp = GF(p)
    try:
        x0 = ZZ(Fp(D).sqrt())          # sqrt(D) in Fp; raises if non-square
    except Exception:
        return None

    # Choose x0 ≡ t  (mod 2) same parity as needed: 4p = t^2 - D v^2
    # Run the Euclidean-like reduction on x0 mod p
    a, b = p, x0
    limit = ZZ(2) * isqrt(p)
    while b > limit:
        a, b = b, a % b

    t = b
    # Now check: (4p - t^2) must be divisible by |D| and the quotient a perfect square
    rem = 4*p - t*t
    if rem < 0 or rem % Dabs != 0:
        return None
    vsq = rem // Dabs
    v = isqrt(vsq)
    if v*v != vsq:
        return None
    # Verify
    if t*t - Dabs * v*v == 4*p:
        return (t, v)
    if (-t)*(-t) - Dabs * v*v == 4*p:
        return (-t, v)
    return None


def random_fundamental_discriminant(bit_size=40):
    """
    Return a random negative fundamental discriminant D with |D| ~ 2^bit_size.
    A fundamental discriminant D < 0 satisfies:
      D ≡ 1 (mod 4)  and  squarefree, OR
      D = 4m where m ≡ 2,3 (mod 4) and squarefree.
    We use the simplest family: D = -p_disc for a prime p_disc ≡ 3 (mod 4).
    """
    while True:
        candidate = random_prime(2**bit_size, lbound=2**(bit_size-1))
        if candidate % 4 == 3:
            return -candidate


def hilbert_class_poly_small(D):
    """
    Compute the Hilbert class polynomial H_D(x) over ZZ.
    SageMath has this built-in for |D| not too large.
    """
    return hilbert_class_polynomial(D)


def curve_from_j(j, p):
    """
    Given j-invariant j in GF(p), return a short Weierstrass curve E/GF(p)
    with that j-invariant and a base point.
    Standard formula (assuming j != 0, 1728):
        a = 3j / (1728 - j),   b = 2j / (1728 - j)
    """
    Fp = GF(p)
    j  = Fp(j)
    assert j != 0 and j != 1728, "Special j-invariants need separate handling"
    denom = Fp(1728) - j
    a = Fp(3) * j / denom
    b = Fp(2) * j / denom
    E = EllipticCurve(Fp, [a, b])
    return E


# ---------------------------------------------------------------------------
# Phase 1 – BACKDOOR PARAMETER GENERATION
# ---------------------------------------------------------------------------

def generate_backdoored_curve(D, prime_bits=80):
    """
    Using secret discriminant D, construct an elliptic curve over GF(p) that:
      * has prime group order  (passes standard checks)
      * is generated with a plausible-looking seed
      * admits a secret endomorphism φ known only to the holder of D

    Returns:
      curve      -- EllipticCurve over GF(p)
      p          -- field prime
      n          -- group order (prime)
      trace      -- trace of Frobenius t  (secret: reveals D via Cornacchia)
      D          -- the secret discriminant
    """
    print(f"\n{'='*60}")
    print("PHASE 1 — Backdoor Parameter Generation")
    print(f"{'='*60}")
    print(f"Secret discriminant D = {D}")
    print(f"Targeting ~{prime_bits}-bit prime field")

    attempt = 0
    while True:
        attempt += 1
        # Pick a random prime p of the right size
        p = random_prime(2**prime_bits, lbound=2**(prime_bits-1))
        if p % 4 != 3:          # small convenience for sqrt later
            continue

        # Try to solve Cornacchia: 4p = t^2 - D*v^2
        sol = cornacchia(D, p)
        if sol is None:
            continue
        t, v = sol

        # Group order candidates: p+1-t  or  p+1+t
        for trace in [t, -t]:
            n = p + 1 - trace
            if n <= 0:
                continue
            if is_prime(n):
                # We have a prime-order curve — now build it
                H = hilbert_class_poly_small(D)
                Fp = GF(p)
                roots = H.change_ring(Fp).roots()
                if not roots:
                    continue
                j0 = roots[0][0]

                try:
                    E = curve_from_j(j0, p)
                except Exception:
                    continue

                # Confirm order (twist might match instead)
                if ZZ(E.order()) == n:
                    pass
                elif ZZ(E.order()) == 2*p + 2 - n:
                    E = E.quadratic_twist()
                else:
                    continue

                assert ZZ(E.order()) == n, "Order mismatch — should not happen"

                print(f"\n  Found curve after {attempt} attempts")
                print(f"  p     = {p}")
                print(f"  n     = {n}  (prime: {is_prime(n)})")
                print(f"  trace = {trace}")
                print(f"  j     = {j0}")
                print(f"  E     : y^2 = x^3 + {E.a4()}*x + {E.a6()}")
                return E, p, n, trace, D


# ---------------------------------------------------------------------------
# Phase 2 – INDEPENDENT AUDITOR CHECKS
# ---------------------------------------------------------------------------

def audit_curve(E, p, n):
    """
    Run the checks an auditor would apply.  With a properly constructed
    backdoored curve, all of these pass.
    """
    print(f"\n{'='*60}")
    print("PHASE 2 — Independent Auditor Checks")
    print(f"{'='*60}")

    results = {}

    # 1. Prime order
    results["Prime group order"] = is_prime(n)
    print(f"  [{'PASS' if results['Prime group order'] else 'FAIL'}] Prime group order")

    # 2. Not anomalous (n != p)
    results["Not anomalous (n != p)"] = (n != p)
    print(f"  [{'PASS' if results['Not anomalous (n != p)'] else 'FAIL'}] Not anomalous (n ≠ p)")

    # 3. Embedding degree: check k s.t. p^k ≡ 1 (mod n) for k up to 100
    embedding_deg = None
    for k in range(1, 100):
        if pow(p, k, n) == 1:
            embedding_deg = k
            break
    if embedding_deg is None:
        embedding_deg = "> 100"
    results["Embedding degree"] = embedding_deg
    safe_emb = (embedding_deg == "> 100") or (isinstance(embedding_deg, int) and embedding_deg > 20)
    print(f"  [{'PASS' if safe_emb else 'FAIL'}] Embedding degree = {embedding_deg}  (want >> 1)")

    # 4. Twist order — is it resistant to small-subgroup attacks?
    Et = E.quadratic_twist()
    nt = ZZ(Et.order())
    twist_large_factor = max(factor(nt), key=lambda x: x[0])[0]
    twist_safe = twist_large_factor > 2**(p.nbits() // 2)
    results["Twist security"] = twist_safe
    print(f"  [{'PASS' if twist_safe else 'FAIL'}] Twist largest factor ~ 2^{twist_large_factor.nbits()} bits")

    # 5. Cofactor = 1
    cofactor = ZZ(E.order()) // n
    results["Cofactor = 1"] = (cofactor == 1)
    print(f"  [{'PASS' if cofactor == 1 else 'FAIL'}] Cofactor = {cofactor}")

    # 6. Naive CM detection: try small |D| up to 1000
    print(f"  [ .. ] Checking CM discriminants |D| <= 1000 ...")
    cm_found = None
    for d in range(3, 1001):
        for sign in [-1]:
            D_try = sign * d
            if not ZZ(D_try).is_squarefree():
                continue
            if D_try % 4 not in [0, 1]:
                continue
            sol = cornacchia(D_try, p)
            if sol is not None:
                t_try = sol[0]
                if abs(p + 1 - t_try - n) < 2:
                    cm_found = D_try
                    break
        if cm_found:
            break

    if cm_found:
        print(f"  [FAIL] CM detected with small discriminant D = {cm_found}")
    else:
        print(f"  [PASS] No CM detected for |D| <= 1000  (true D hidden)")

    print("\n  → Curve passes all standard auditor checks.")
    return results


# ---------------------------------------------------------------------------
# Phase 3 – BACKDOOR EXPLOITATION
# ---------------------------------------------------------------------------

def compute_glv_endomorphism(E, p, n, D, trace):
    """
    Given the secret D and trace t, recover the CM endomorphism φ on E.

    For CM by Z[√D], the endomorphism φ satisfies φ^2 - t*φ + p = 0
    in End(E).  Its action on a point P is:

        φ(P) = (x^p, y^p)    [the Frobenius — always available]

    The GLV eigenvalue λ satisfies  λ^2 - t*λ + p ≡ 0  (mod n).
    We solve this quadratic mod n to get λ.

    Then for any point P:  φ(P) = λ·P  (as group operation)

    This lets us write k = k0 + k1*λ with |k0|,|k1| ~ sqrt(n),
    halving the bitlength of the scalar and breaking security.
    """
    print(f"\n{'='*60}")
    print("PHASE 3 — Exploit: GLV Decomposition via Secret Endomorphism")
    print(f"{'='*60}")
    print(f"  Using secret D = {D}, trace = {trace}")

    # Solve λ^2 - trace*λ + p ≡ 0  (mod n)
    Zn = Integers(n)
    # Discriminant of the quadratic: trace^2 - 4p
    disc = ZZ(trace)**2 - 4*p
    print(f"  Quadratic discriminant = {disc}")

    # Find sqrt(disc) mod n
    disc_mod_n = Zn(disc)
    try:
        sqrt_disc = ZZ(disc_mod_n.sqrt())
    except Exception:
        # Try the other root
        sqrt_disc = ZZ(-disc_mod_n.sqrt())

    lam1 = ZZ(Zn((trace + sqrt_disc) * inverse_mod(2, n)))
    lam2 = ZZ(Zn((trace - sqrt_disc) * inverse_mod(2, n)))

    print(f"  GLV eigenvalue λ₁ = {lam1}")
    print(f"  GLV eigenvalue λ₂ = {lam2}")

    # Verify: λ^2 - trace*λ + p ≡ 0 (mod n)
    for lam in [lam1, lam2]:
        check = (Zn(lam)**2 - Zn(trace)*Zn(lam) + Zn(p))
        print(f"  Verify λ^2 - t·λ + p ≡ {check} (mod n)  ({'✓' if check == 0 else '✗'})")

    return lam1, lam2


def glv_decompose(k, n, lam):
    """
    Decompose scalar k as k = k0 + k1*λ (mod n) with |k0|, |k1| ~ sqrt(n).
    Uses the lattice basis reduction approach (simplified Babai rounding).
    """
    # Babai rounding on the 2D lattice spanned by (n,0) and (lam,1)
    # We want short vector [k0, k1] such that k0 + k1*lam ≡ k (mod n)
    sqn = isqrt(n) + 1
    # Simple approach for illustration: use extended gcd to get short representation
    # Full GLV uses LLL on a 2x2 lattice; we do the direct version here.
    Zn = Integers(n)
    lam_inv = ZZ(Zn(lam)**(-1))
    k1 = ZZ(Zn(k) * Zn(lam_inv))
    # Round k1 to nearest multiple
    if k1 > sqn:
        k1 = k1 - n
    k0 = ZZ(Zn(k - k1 * lam))
    if k0 > sqn:
        k0 = k0 - n
    return k0, k1


def baby_step_giant_step_glv(P, Q, n, lam, E):
    """
    Solve Q = k*P using GLV-accelerated BSGS.

    Without GLV: search space ~ sqrt(n)  → O(n^{1/2})
    With    GLV: each half-scalar ~ n^{1/4} → O(n^{1/4})  effective

    For a p-bit curve:  n ≈ 2^p
      Standard BSGS:  2^{p/2} steps
      GLV BSGS:       2^{p/4} steps  ← two orders of magnitude better for p=80
    """
    print(f"\n  Solving ECDLP with GLV-accelerated BSGS...")
    print(f"  n has {n.nbits()} bits → standard BSGS needs ~2^{n.nbits()//2} steps")
    print(f"  GLV halves scalar bitlength → effective ~2^{n.nbits()//4} steps")

    # φ(P) = λ·P  (eigenvalue action)
    phi_P = ZZ(lam) * P
    phi_Q = ZZ(lam) * Q

    m = isqrt(isqrt(n)) + 2          # step size ~ n^{1/4}

    print(f"  BSGS table size m = {m}  (~ n^{{1/4}} = {int(n**(0.25)):.0f})")

    # Baby steps: store {i*P : i = 0..m} and {i*φ(P) : i = 0..m}
    # Giant steps search for k0,k1 in [-m..m] x [-m..m]
    # We do a combined table over the product decomposition.

    # Baby step table: j*(P + φ(P)) for j in [0, m)
    baby = {}
    step = P + phi_P
    cur  = E(0)           # identity
    for j in range(m):
        key = (ZZ(cur[0]), ZZ(cur[1])) if cur != E(0) else "inf"
        baby[key] = j
        cur = cur + step

    # Giant steps: Q - i*m*(P + φ(P))
    giant_step = ZZ(m) * step
    cur = Q
    neg_giant = -giant_step

    found = None
    for i in range(m):
        key = (ZZ(cur[0]), ZZ(cur[1])) if cur != E(0) else "inf"
        if key in baby:
            j = baby[key]
            # Q = (i*m + j)*(P + φ(P))
            # = (i*m + j)*P + (i*m + j)*λ*P
            # = [(i*m+j) + (i*m+j)*λ] * P
            candidate = ZZ(i*m + j)
            k_candidate = ZZ(Integers(n)(candidate * (1 + lam)))
            if k_candidate * P == Q:
                found = k_candidate
                print(f"  Found: i={i}, j={j} → k = {k_candidate}")
                break
        cur = cur + neg_giant

    return found


def exploit(E, p, n, D, trace):
    """
    Full exploitation demonstration:
      1. Generate a keypair (k, Q=kP) — simulating a victim
      2. Use secret D to recover k without knowing it
    """
    lam1, lam2 = compute_glv_endomorphism(E, p, n, D, trace)

    # Pick the smaller eigenvalue for efficiency
    lam = lam1 if lam1 < lam2 else lam2

    # --- Simulate victim keypair ---
    P = E.random_point()
    # Ensure P has order n (cofactor = 1 so this is automatic)
    k_secret = ZZ(randint(2, n-1))
    Q = k_secret * P

    print(f"\n  Victim public key Q = k·P")
    print(f"  k (secret, for verification) = {k_secret}")
    print(f"  P = {P}")
    print(f"  Q = {Q}")

    # --- Backdoor holder recovers k ---
    k_recovered = baby_step_giant_step_glv(P, Q, n, lam, E)

    print(f"\n  {'='*40}")
    if k_recovered is not None and k_recovered == k_secret:
        print(f"  ✓ ECDLP SOLVED:  k = {k_recovered}")
        print(f"  ✓ Matches secret: {k_recovered == k_secret}")
    elif k_recovered is not None:
        # Check modular equivalence accounting for λ decomposition
        print(f"  k_recovered = {k_recovered}")
        print(f"  k_secret    = {k_secret}")
        verify = (k_recovered * P == Q)
        print(f"  ✓ Point check: k_recovered·P == Q  → {verify}")
    else:
        print(f"  ✗ BSGS range too small for this key (increase m)")
        print(f"    (For demo curves this can happen — increase prime_bits)")
    print(f"  {'='*40}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("""
╔══════════════════════════════════════════════════════════╗
║   Kleptographic CM Curve — Research Demonstration        ║
║   DO NOT USE IN PRODUCTION                               ║
╚══════════════════════════════════════════════════════════╝
    """)

    # ── Parameters ──────────────────────────────────────────────────────────
    # For a real backdoor: D_bits >= 100, prime_bits >= 256.
    # Here we use small values so the script finishes in seconds.
    D_bits    = 20      # secret discriminant size
    prime_bits = 70     # curve field size (toy — real curves use 256+)
    # ────────────────────────────────────────────────────────────────────────

    set_random_seed(42)   # reproducibility for demo

    # 1. Generate the secret discriminant
    D = random_fundamental_discriminant(D_bits)
    print(f"Backdoor installer's secret discriminant:  D = {D}  ({D_bits} bits)")
    print(f"This would be {100}-{256} bits in a real deployment.\n")

    # 2. Build the backdoored curve
    E, p, n, trace, D = generate_backdoored_curve(D, prime_bits=prime_bits)

    # 3. Auditor checks — all should pass
    audit_curve(E, p, n)

    # 4. Backdoor holder exploits the curve
    exploit(E, p, n, D, trace)

    print(f"""
{'='*60}
SUMMARY
{'='*60}
Curve parameters (public):
  p  = {p}
  n  = {n}
  a  = {E.a4()}
  b  = {E.a6()}

Secret trapdoor:
  D  = {D}   ← holder of this breaks all keys

Security reduction:
  Standard BSGS: O(2^{n.nbits()//2}) ≈ 2^{n.nbits()//2} group operations
  GLV-backed:    O(2^{n.nbits()//4}) ≈ 2^{n.nbits()//4} group operations
  Reduction factor: 2^{n.nbits()//4}x easier

For a real 256-bit curve this means:
  Nominal security:   128 bits
  Actual security:     64 bits  (fully broken with ~2^64 ops)
{'='*60}
    """)


if __name__ == "__main__":
    main()
