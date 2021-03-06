#Android makefile to build kernel as a part of Android Build
PERL		= perl

ifeq ($(TARGET_PREBUILT_KERNEL),)
INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_IMG=$(KERNEL_OUT)/arch/arm/boot/Image

MSM_ARCH ?= $(shell $(PERL) -e 'while (<>) {$$a = $$1 if /CONFIG_ARCH_((?:MSM|QSD)[a-zA-Z0-9]+)=y/; $$r = $$1 if /CONFIG_MSM_SOC_REV_(?!NONE)(\w+)=y/;} print lc("$$a$$r\n");' $(KERNEL_CONFIG))
KERNEL_USE_OF ?= $(shell $(PERL) -e '$$of = "n"; while (<>) { if (/CONFIG_USE_OF=y/) { $$of = "y"; break; } } print $$of;' kernel/arch/arm/configs/$(KERNEL_DEFCONFIG))

ifeq "$(KERNEL_USE_OF)" "y"
DTS_NAME ?= $(MSM_ARCH)
DTS_FILES = $(wildcard $(TOP)/kernel/arch/arm/boot/dts/$(DTS_NAME)*.dts)
DTS_FILE = $(lastword $(subst /, ,$(1)))
DTB_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%.dtb,$(call DTS_FILE,$(1))))
ZIMG_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%-zImage,$(call DTS_FILE,$(1))))
KERNEL_ZIMG = $(KERNEL_OUT)/arch/arm/boot/zImage
DTC = $(KERNEL_OUT)/scripts/dtc/dtc

define append-dtb
mkdir -p $(KERNEL_OUT)/arch/arm/boot;\
$(foreach d, $(DTS_FILES), \
   $(DTC) -p 1024 -O dtb -o $(call DTB_FILE,$(d)) $(d); \
   cat $(KERNEL_ZIMG) $(call DTB_FILE,$(d)) > $(call ZIMG_FILE,$(d));)
endef
else

define append-dtb
endef
endif

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

# 20131223 LS1-p13795 modified for exFAT file system
ifeq ($(PANTECH_SDXC_EXFAT_FS),true)
ifeq ($(PANTECH_SDXC_EXFAT_BUILD),true)
define exfat-module
if test -e kheaders*.tar.bz2;then\
rm -rf kheaders*.tar.bz2;\
fi
if test -e tuxera-exfat-*-apq8064*.tgz;then\
rm -rf tuxera_exfat_hash;\
rm -rf tuxera-exfat-*-apq8064*.tgz;\
rm -rf tuxera-exfat-*-apq8064*;\
fi
if test -e tuxera-exfat-*-msm8974*.tgz;then\
rm -rf tuxera_exfat_hash;\
rm -rf tuxera-exfat-*-msm8974*.tgz;\
rm -rf tuxera-exfat-*-msm8974*;\
fi
./tuxera_update.sh --source-dir $(TOP)/kernel --output-dir $(KERNEL_OUT) -a --target target/pantech.d/apq8064 --user pantech --pass feke57aze93ni --use-cache --cache-dir $(TOP)/tuxera_exfat_hash
tar -xvzf tuxera-exfat-*-apq8064*.tgz
cp tuxera-exfat-*-apq8064*/exfat/kernel-module/texfat.ko $(KERNEL_MODULES_OUT)
mdpath=`find $(TARGET_OUT) -type d -name bin`;\
if [ "$$mdpath" == "" ];then\
mkdir -p $(TARGET_OUT)/bin;\
fi
cp tuxera-exfat-*-apq8064*/exfat/tools/* $(TARGET_OUT)/bin
endef
else
define exfat-module
cp tuxera-exfat-*-apq8064*/exfat/kernel-module/texfat.ko $(KERNEL_MODULES_OUT)
cp tuxera-exfat-*-apq8064*/exfat/tools/* $(TARGET_OUT)/bin
endef
endif
else
define exfat-module
endef
endif

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- $(KERNEL_DEFCONFIG)

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi-
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- modules
	$(MAKE) -C kernel O=../$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP=1 ARCH=arm CROSS_COMPILE=arm-eabi- modules_install
	$(mv-modules)
	$(clean-module-folder)
	$(append-dtb)
	$(exfat-module)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- headers_install

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/arm/configs/$(KERNEL_DEFCONFIG)

endif
