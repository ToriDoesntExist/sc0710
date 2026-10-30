{ config, pkgs, lib, ... }:
let
    kernel = config.hardware.sc0710.kernelPackages.kernel;
    minimumKernel = "6.12";
    currentKernelMajorMinor = lib.versions.majorMinor kernel.version;

    package-version = lib.fileContents ./version;

    cli = pkgs.writeShellScriptBin "sc0710-cli" (builtins.readFile ./scripts/sc0710-cli.sh);

    driver = pkgs.stdenv.mkDerivation rec {
        name = "sc0710-${package-version}-${kernel.version}";
        version = package-version;

        enableParallelBuilding = true;

        src = ./.;
        nativeBuildInputs = kernel.moduleBuildDependencies;

        makeFlags = [
            "KBUILD_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        ];

        installPhase = ''
            mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/pci/
            install -D build/sc0710.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/pci/
        '';
    };
in
{
    options = {
        hardware.sc0710 = {
            enable = lib.mkEnableOption "Enable the sc0710 kernel module";
            kernelPackages = lib.mkOption {
                default = config.boot.kernelPackages;
            };
        };
    };
    config = (lib.mkIf (config.hardware.sc0710.enable) {
        assertions = [
               {
                assertion = lib.versionAtLeast currentKernelMajorMinor minimumKernel;
                message = "sc0710 driver is not compatible with kernel ${currentKernelMajorMinor}. It requires at least version ${minimumKernel}.";
            }
        ];

        boot.extraModulePackages   = [ driver   ];
        boot.kernelModules         = [ "sc0710" ];
        environment.systemPackages = [ cli      ];

        # 4K Pro only: the driver programs the ECP5 FPGA during probe and needs
        # SC0710.FWI.HEX on disk; provision it once with scripts/extract-firmware.sh
        # (installs to /lib/firmware/sc0710, which the kernel loader reads directly).
    });
}
