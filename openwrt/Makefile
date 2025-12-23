include $(TOPDIR)/rules.mk

PKG_NAME:=nodewatcher-agent
PKG_VERSION:=1.1.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
CMAKE_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

# Enable http_push module with libcurl (compiled from feeds)
CMAKE_OPTIONS += -DHTTP_PUSH_MODULE=ON

define Package/nodewatcher-agent/default
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=Nodewatcher agent daemon
  DEPENDS:=+libubus +libubox +libjson-c
endef

define Package/nodewatcher-agent
  $(Package/nodewatcher-agent/default)
  DEPENDS+= +libuci +libblobmsg-json
endef

define Package/nodewatcher-agent/description
  Nodewatcher agent daemon
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/src/* $(PKG_BUILD_DIR)/
endef

define Package/nodewatcher-agent/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nodewatcher-agent $(1)/usr/bin/nodewatcher-agent
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libnodewatcher-agent-common.so $(1)/usr/lib/
endef

# 1: module name
# 2: extra dependencies
define BuildModule
  define Package/nodewatcher-agent-mod-$(1)
    $(Package/nodewatcher-agent/default)
    TITLE+= ($(1) module)
    DEPENDS+=nodewatcher-agent $(2)
  endef
  define Package/nodewatcher-agent-mod-$(1)/install
	$(INSTALL_DIR) $$(1)/usr/lib/nodewatcher-agent
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/$(1).so $$(1)/usr/lib/nodewatcher-agent/
  endef
  $$(eval $$(call BuildPackage,nodewatcher-agent-mod-$(1)))
endef

$(eval $(call BuildPackage,nodewatcher-agent))
$(eval $(call BuildModule,general,))
$(eval $(call BuildModule,resources,))
$(eval $(call BuildModule,interfaces,))
$(eval $(call BuildModule,wireless,+libiwinfo))
$(eval $(call BuildModule,keys_ssh,))
$(eval $(call BuildModule,clients,))
$(eval $(call BuildModule,routing_babel,))
$(eval $(call BuildModule,routing_olsr,))
$(eval $(call BuildModule,meshpoint,))
$(eval $(call BuildModule,http_push,+libcurl))
