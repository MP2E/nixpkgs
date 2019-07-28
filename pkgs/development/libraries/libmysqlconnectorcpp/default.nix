{ stdenv, fetchurl, cmake, boost, mysql, openssl, zlib }:

stdenv.mkDerivation rec {
  name = "libmysqlconnectorcpp-${version}";
  version = "8.0.16";

  src = fetchurl {
    url = "https://cdn.mysql.com/Downloads/Connector-C++/mysql-connector-c++-${version}-src.tar.gz";
    sha256 = "1447hfwc8rnizxc20jgrwmg8mdj90zljs694w96vgsf7sj28li66";
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
