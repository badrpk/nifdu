#pragma once

#include <algorithm>
#include <cstddef>
#include <string>
#include <string_view>

#include <boost/beast/http.hpp>
#include <boost/iostreams/device/back_inserter.hpp>
#include <boost/iostreams/filtering_stream.hpp>
#include <boost/iostreams/filter/gzip.hpp>

#if defined(HAVE_BROTLI) && !defined(BOOST_IOSTREAMS_NO_BROTLI)
  #include <boost/iostreams/filter/brotli.hpp>
  #define NIFDU_HAVE_BROTLI 1
#else
  #define NIFDU_HAVE_BROTLI 0
#endif

namespace nifdu {
  namespace beast = boost::beast;
  namespace http  = beast::http;
  namespace bio   = boost::iostreams;

  inline bool nifdu_accepts(const std::string& hdr, std::string_view token){
    std::string h = hdr, t(token);
    std::transform(h.begin(),h.end(),h.begin(),::tolower);
    std::transform(t.begin(),t.end(),t.begin(),::tolower);
    return h.find(t) != std::string::npos;
  }

  enum class nifdu_enc { none, gzip, br };

  template<class Request>
  inline nifdu_enc nifdu_choose_encoding(const Request& req, std::size_t body_size, std::size_t min_bytes = 512){
    if (body_size < min_bytes) return nifdu_enc::none;
    auto it = req.find(http::field::accept_encoding);
    std::string ae = (it != req.end()) ? std::string(it->value()) : std::string{};
    if (NIFDU_HAVE_BROTLI && nifdu_accepts(ae, "br"))   return nifdu_enc::br;
    if (nifdu_accepts(ae, "gzip"))                      return nifdu_enc::gzip;
    return nifdu_enc::none;
  }

  inline std::string nifdu_compress_gzip(std::string_view data, int level = 6){
    std::string out;
    bio::filtering_ostream fos;
    fos.push(bio::gzip_compressor(bio::gzip_params(level)));
    fos.push(bio::back_inserter(out));
    fos.write(data.data(), std::streamsize(data.size()));
    fos.flush();
    return out;
  }

#if NIFDU_HAVE_BROTLI
  inline std::string nifdu_compress_br(std::string_view data /* default params */){
    std::string out;
    bio::filtering_ostream fos;
    fos.push(bio::brotli_compressor());
    fos.push(bio::back_inserter(out));
    fos.write(data.data(), std::streamsize(data.size()));
    fos.flush();
    return out;
  }
#endif

  // Build a (possibly) compressed response from a string body
  template<class Request>
  inline http::response<http::string_body>
  nifdu_make_compressed_response(
      const Request& req,
      http::status code,
      std::string body,
      bool keep_alive = true,
      std::string_view content_type = "text/plain; charset=utf-8",
      std::size_t min_bytes = 512)
  {
    const auto which = nifdu_choose_encoding(req, body.size(), min_bytes);

    if (which == nifdu_enc::gzip){
      std::string gz = nifdu_compress_gzip(body);
      http::response<http::string_body> res{code, req.version()};
      res.set(http::field::content_type, content_type);
      res.set(http::field::content_encoding, "gzip");
      res.keep_alive(keep_alive);
      res.body() = std::move(gz);
      res.content_length(res.body().size());
      return res;
    }
#if NIFDU_HAVE_BROTLI
    if (which == nifdu_enc::br){
      std::string br = nifdu_compress_br(body);
      http::response<http::string_body> res{code, req.version()};
      res.set(http::field::content_type, content_type);
      res.set(http::field::content_encoding, "br");
      res.keep_alive(keep_alive);
      res.body() = std::move(br);
      res.content_length(res.body().size());
      return res;
    }
#endif
    http::response<http::string_body> res{code, req.version()};
    res.set(http::field::content_type, content_type);
    res.keep_alive(keep_alive);
    res.body() = std::move(body);
    res.content_length(res.body().size());
    return res;
  }
} // namespace nifdu


