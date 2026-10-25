(() => {
  const cfg = window.APP_CONFIG;
  const redirectUri = window.location.origin + "/";
  const $ = (id) => document.getElementById(id);

  const base64url = (buf) =>
    btoa(String.fromCharCode(...new Uint8Array(buf)))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const randomString = (bytes) => {
    const a = new Uint8Array(bytes);
    crypto.getRandomValues(a);
    return base64url(a);
  };

  const sha256 = (s) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));

  function setStatus(message, isError = false) {
    const el = $("status");
    el.textContent = message;
    el.className = isError ? "error" : "";
  }

  function decodeToken(token) {
    try {
      const payload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      const json = decodeURIComponent(
        atob(payload).split("").map((c) => "%" + c.charCodeAt(0).toString(16).padStart(2, "0")).join("")
      );
      return JSON.parse(json);
    } catch (e) {
      return null;
    }
  }

  function currentToken() {
    const token = sessionStorage.getItem("id_token");
    const claims = token && decodeToken(token);
    if (!claims || claims.exp * 1000 <= Date.now()) {
      sessionStorage.removeItem("id_token");
      return null;
    }
    return { token, claims };
  }

  // Authorization Code + PKCE
  async function login() {
    const verifier = randomString(32);
    const state = randomString(16);
    sessionStorage.setItem("pkce_verifier", verifier);
    sessionStorage.setItem("oauth_state", state);

    const params = new URLSearchParams({
      response_type: "code",
      client_id: cfg.clientId,
      redirect_uri: redirectUri,
      scope: "openid email profile",
      state,
      code_challenge: base64url(await sha256(verifier)),
      code_challenge_method: "S256",
    });
    window.location.assign(`${cfg.cognitoDomain}/oauth2/authorize?${params}`);
  }

  async function handleCallback() {
    const query = new URLSearchParams(window.location.search);
    const code = query.get("code");
    if (!code) return;

    window.history.replaceState({}, "", redirectUri);

    if (query.get("state") !== sessionStorage.getItem("oauth_state")) {
      setStatus("로그인 검증(state)에 실패했습니다. 다시 로그인해 주세요.", true);
      return;
    }

    const res = await fetch(`${cfg.cognitoDomain}/oauth2/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        client_id: cfg.clientId,
        code,
        redirect_uri: redirectUri,
        code_verifier: sessionStorage.getItem("pkce_verifier") || "",
      }),
    });

    sessionStorage.removeItem("pkce_verifier");
    sessionStorage.removeItem("oauth_state");

    if (!res.ok) {
      setStatus("토큰을 받지 못했습니다. 다시 로그인해 주세요.", true);
      return;
    }
    const tokens = await res.json();
    sessionStorage.setItem("id_token", tokens.id_token);
  }

  async function requestAccess() {
    const session = currentToken();
    if (!session) {
      render();
      setStatus("로그인이 만료되었습니다. 다시 로그인해 주세요.", true);
      return;
    }

    $("access-btn").disabled = true;
    setStatus("요청 중입니다...");
    try {
      const res = await fetch(`${cfg.apiEndpoint}/access`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: session.token },
        // 화면은 분 단위, API 는 시간 단위
        body: JSON.stringify({ hours: Number($("minutes").value) / 60 }),
      });
      const data = await res.json().catch(() => ({}));

      if (res.status === 401) {
        sessionStorage.removeItem("id_token");
        render();
        setStatus("인증에 실패했습니다. 다시 로그인해 주세요.", true);
      } else if (!res.ok) {
        setStatus(`요청에 실패했습니다. ${data.message || ""}`, true);
      } else {
        const until = new Date(data.expires_at * 1000).toLocaleString("ko-KR");
        let text = `허용된 IP: ${data.ip}\n포트: ${data.ports.join(", ")}\n만료: ${until}\n서버를 시작했습니다. 부팅까지 1~2분 걸립니다.`;
        if (data.warning) text += `\n참고: ${data.warning}`;
        setStatus(text);
      }
    } catch (e) {
      setStatus("서버에 연결하지 못했습니다.", true);
    } finally {
      $("access-btn").disabled = false;
    }
  }

  function logout() {
    sessionStorage.removeItem("id_token");
    const params = new URLSearchParams({ client_id: cfg.clientId, logout_uri: redirectUri });
    window.location.assign(`${cfg.cognitoDomain}/logout?${params}`);
  }

  function render() {
    const session = currentToken();
    $("login-panel").hidden = !!session;
    $("access-panel").hidden = !session;
    if (session) $("user-email").textContent = session.claims.email || session.claims.sub;
  }

  $("login-btn").addEventListener("click", login);
  $("access-btn").addEventListener("click", requestAccess);
  $("logout-btn").addEventListener("click", logout);

  handleCallback().finally(render);
})();
