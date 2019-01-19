{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.mysql;

  mysql = cfg.package;

  isMariaDB =
    let
      pName = _p: (builtins.parseDrvName (_p.name)).name;
    in pName mysql == pName pkgs.mariadb;
  isMysqlAtLeast57 =
    let
      pName = _p: (builtins.parseDrvName (_p.name)).name;
    in (pName mysql == pName pkgs.mysql57)
       && ((builtins.compareVersions mysql.version "5.7") >= 0);

  pidFile = "${cfg.pidDir}/mysqld.pid";

  mysqldAndInstallOptions =
    "--user=${cfg.user} --datadir=${cfg.dataDir} --basedir=${mysql}";
  mysqldOptions =
    "${mysqldAndInstallOptions} --pid-file=${pidFile}";
  # For MySQL 5.7+, --insecure creates the root user without password
  # (earlier versions and MariaDB do this by default).
  installOptions =
    "${mysqldAndInstallOptions} ${lib.optionalString isMysqlAtLeast57 "--insecure"}";

in

{

  ###### interface

  options = {

    services.mysql = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = "
          Whether to enable the MySQL server.
        ";
      };

      package = mkOption {
        type = types.package;
        example = literalExample "pkgs.mysql";
        description = "
          Which MySQL derivation to use. MariaDB packages are supported too.
        ";
      };

      bind = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample "0.0.0.0";
        description = "Address to bind to. The default is to bind to all addresses";
      };

      port = mkOption {
        type = types.int;
        default = 3306;
        description = "Port of MySQL";
      };

      user = mkOption {
        type = types.str;
        default = "mysql";
        description = "User account under which MySQL runs";
      };

      dataDir = mkOption {
        type = types.path;
        example = "/var/lib/mysql";
        description = "Location where MySQL stores its table files";
      };

      pidDir = mkOption {
        default = "/run/mysqld";
        description = "Location of the file which stores the PID of the MySQL server";
      };

      extraOptions = mkOption {
        type = types.lines;
        default = "";
        example = ''
          key_buffer_size = 6G
          table_cache = 1600
          log-error = /var/log/mysql_err.log
        '';
        description = ''
          Provide extra options to the MySQL configuration file.

          Please note, that these options are added to the
          <literal>[mysqld]</literal> section so you don't need to explicitly
          state it again.
        '';
      };

      initialDatabases = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = ''
                The name of the database to create.
              '';
            };
            schema = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                The initial schema of the database; if null (the default),
                an empty database is created.
              '';
            };
          };
        });
        default = [];
        description = ''
          List of database names and their initial schemas that should be used to create databases on the first startup
          of MySQL. The schema attribute is optional: If not specified, an empty database is created.
        '';
        example = [
          { name = "foodatabase"; schema = literalExample "./foodatabase.sql"; }
          { name = "bardatabase"; }
        ];
      };

      initialScript = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "A file containing SQL statements to be executed on the first startup. Can be used for granting certain permissions on the database";
      };

      ensureDatabases = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Ensures that the specified databases exist.
          This option will never delete existing databases, especially not when the value of this
          option is changed. This means that databases created once through this option or
          otherwise have to be removed manually.
        '';
        example = [
          "nextcloud"
          "matomo"
        ];
      };

      ensureUsers = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = ''
                Name of the user to ensure.
              '';
            };
            ensurePermissions = mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = ''
                Permissions to ensure for the user, specified as attribute set.
                The attribute names specify the database and tables to grant the permissions for,
                separated by a dot. You may use wildcards here.
                The attribute values specfiy the permissions to grant.
                You may specify one or multiple comma-separated SQL privileges here.

                For more information on how to specify the target
                and on which privileges exist, see the
                <link xlink:href="https://mariadb.com/kb/en/library/grant/">GRANT syntax</link>.
                The attributes are used as <code>GRANT ''${attrName} ON ''${attrValue}</code>.
              '';
              example = literalExample ''
                {
                  "database.*" = "ALL PRIVILEGES";
                  "*.*" = "SELECT, LOCK TABLES";
                }
              '';
            };
          };
        });
        default = [];
        description = ''
          Ensures that the specified users exist and have at least the ensured permissions.
          The MySQL users will be identified using Unix socket authentication. This authenticates the Unix user with the
          same name only, and that without the need for a password.
          This option will never delete existing users or remove permissions, especially not when the value of this
          option is changed. This means that users created and permissions assigned once through this option or
          otherwise have to be removed manually.
        '';
        example = literalExample ''
          [
            {
              name = "nextcloud";
              ensurePermissions = {
                "nextcloud.*" = "ALL PRIVILEGES";
              };
            }
            {
              name = "backup";
              ensurePermissions = {
                "*.*" = "SELECT, LOCK TABLES";
              };
            }
          ]
        '';
      };

      # FIXME: remove this option; it's a really bad idea.
      rootPassword = mkOption {
        default = null;
        description = "Path to a file containing the root password, modified on the first startup. Not specifying a root password will leave the root password empty.";
      };

      replication = {
        role = mkOption {
          type = types.enum [ "master" "slave" "none" ];
          default = "none";
          description = "Role of the MySQL server instance.";
        };

        serverId = mkOption {
          type = types.int;
          default = 1;
          description = "Id of the MySQL server instance. This number must be unique for each instance";
        };

        masterHost = mkOption {
          type = types.str;
          description = "Hostname of the MySQL master server";
        };

        slaveHost = mkOption {
          type = types.str;
          description = "Hostname of the MySQL slave server";
        };

        masterUser = mkOption {
          type = types.str;
          description = "Username of the MySQL replication user";
        };

        masterPassword = mkOption {
          type = types.str;
          description = "Password of the MySQL replication user";
        };

        masterPort = mkOption {
          type = types.int;
          default = 3306;
          description = "Port number on which the MySQL master server runs";
        };
      };
    };

  };


  ###### implementation

  config = mkIf config.services.mysql.enable {

    services.mysql.dataDir =
      mkDefault (if versionAtLeast config.system.stateVersion "17.09" then "/var/lib/mysql"
                 else "/var/mysql");

    users.users.mysql = {
      description = "MySQL server user";
      group = "mysql";
      uid = config.ids.uids.mysql;
    };

    users.groups.mysql.gid = config.ids.gids.mysql;

    environment.systemPackages = [mysql];

    environment.etc."my.cnf".text =
    ''
      [mysqld]
      port = ${toString cfg.port}
      datadir = ${cfg.dataDir}
      ${optionalString (cfg.bind != null) "bind-address = ${cfg.bind}" }
      ${optionalString (cfg.replication.role == "master" || cfg.replication.role == "slave") "log-bin=mysql-bin"}
      ${optionalString (cfg.replication.role == "master" || cfg.replication.role == "slave") "server-id = ${toString cfg.replication.serverId}"}
      ${optionalString (cfg.ensureUsers != [])
      ''
        plugin-load-add = auth_socket.so
      ''}
      ${cfg.extraOptions}
    '';

    systemd.services.mysql = let
      hasNotify = (cfg.package == pkgs.mariadb);
    in {
        description = "MySQL Server";

        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ config.environment.etc."my.cnf".source ];

        unitConfig.RequiresMountsFor = "${cfg.dataDir}";

        path = [
          # Needed for the mysql_install_db command in the preStart script
          # which calls the hostname command.
          pkgs.nettools
        ];

        preStart =
          ''
            if ! test -e ${cfg.dataDir}/mysql; then
                mkdir -m 0700 -p ${cfg.dataDir}
                chown -R ${cfg.user} ${cfg.dataDir}
                ${mysql}/bin/mysqld --defaults-file=/etc/my.cnf --initialize ${mysqldOptions}
                touch /tmp/mysql_init
            fi

            mkdir -m 0755 -p ${cfg.pidDir}
            chown -R ${cfg.user} ${cfg.pidDir}
          '';

        serviceConfig = {
          Type = if hasNotify then "notify" else "simple";
          RuntimeDirectory = "mysqld";
          ExecStart = "${mysql}/bin/mysqld --defaults-file=/etc/my.cnf ${mysqldOptions}";
        };

      };

  };

}
