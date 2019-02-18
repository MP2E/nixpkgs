{ stdenv, fetchurl, cmake, boost, mysql, openssl, zlib }:

stdenv.mkDerivation rec {
  name = "libmysqlconnectorcpp-${version}";
  version = "8.0.15";

  src = fetchurl {
    url = "https://cdn.mysql.com/Downloads/Connector-C++/mysql-connector-c++-${version}-src.tar.gz";
    sha256 = "10bvabmk4wh4a082a4c43fz6hhywk5qwlq14gg79xs6hwyz9rr5p";
  };

  buildInputs = [ cmake boost mysql openssl zlib ];

  cmakeFlags = [ "-DMYSQL_LIB_DIR=${mysql}/lib" "-DWITH_JDBC=ON" ];

  meta = {
    homepage = https://dev.mysql.com/downloads/connector/cpp/;
    description = "C++ library for connecting to mysql servers.";
    license = stdenv.lib.licenses.gpl2;
    platforms = stdenv.lib.platforms.unix;
  };
}
