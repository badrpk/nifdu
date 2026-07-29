#include "tls_sni.hpp"

SniManager mgr;  // global, as before

void load_all_certs() {
    // These are your fallback/static certs (optional — you can keep them until on-demand works)
    mgr.add_or_update("nifdu.com",
        "C:/nifdu/certs/nifdu.com/fullchain.pem",
        "C:/nifdu/certs/nifdu.com/privkey.pem");

    mgr.add_or_update("bijli.live",
        "C:/nifdu/certs/bijli.live/fullchain.pem",
        "C:/nifdu/certs/bijli.live/privkey.pem");

    mgr.add_or_update("sophyane.com",
        "C:/nifdu/certs/sophyane.com/fullchain.pem",
        "C:/nifdu/certs/sophyane.com/privkey.pem");

    mgr.add_or_update("visas.solutions",
        "C:/nifdu/certs/visas.solutions/fullchain.pem",
        "C:/nifdu/certs/visas.solutions/privkey.pem");
}