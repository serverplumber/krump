{ pkgs }:

{
  # Minimal static file server container
  # Pattern: build artifacts elsewhere, drop them here, serve them
  # Examples:
  #   - HTML/CSS/JS from a build step
  #   - JAR files with jetty
  #   - Docker images from other builders

  image = pkgs.dockerTools.buildImage {
    name = "staticserver";
    tag = "latest";

    # darkhttpd is a single statically-linked binary, nothing else needed
    copyToRoot = pkgs.buildEnv {
      name = "staticserver-root";
      paths = [ pkgs.darkhttpd ];
    };

    config = {
      # Run darkhttpd serving /assets on port 8080
      Cmd = [
        "${pkgs.darkhttpd}/bin/darkhttpd"
        "/assets"
        "--port"
        "8080"
        "--addr"
        "0.0.0.0"
      ];
      ExposedPorts = {
        "8080/tcp" = { };
      };
      WorkingDir = "/assets";
    };
  };
}
