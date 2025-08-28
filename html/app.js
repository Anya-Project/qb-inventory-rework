const InventoryContainer = Vue.createApp({
  data() {
    return this.getInitialState();
  },
  computed: {
    playerWeight() {
      const weight = Object.values(this.playerInventory).reduce(
        (total, item) => {
          if (item && item.weight !== undefined && item.amount !== undefined) {
            return total + item.weight * item.amount;
          }
          return total;
        },
        0
      );
      return isNaN(weight) ? 0 : weight;
    },
    otherInventoryWeight() {
      const weight = Object.values(this.otherInventory).reduce(
        (total, item) => {
          if (item && item.weight !== undefined && item.amount !== undefined) {
            return total + item.weight * item.amount;
          }
          return total;
        },
        0
      );
      return isNaN(weight) ? 0 : weight;
    },
  },
  watch: {
    transferAmount(newVal) {
      if (newVal !== null && newVal < 1) this.transferAmount = 1;
    },
  },
  methods: {
    getInitialState() {
      return {
        maxWeight: 0,
        totalSlots: 0,
        isInventoryOpen: false,
        isOtherInventoryEmpty: true,
        errorSlot: null,
        playerInventory: {},
        inventoryLabel: "Inventory",
        otherInventory: {},
        otherInventoryName: "",
        otherInventoryLabel: "Drop",
        otherInventoryMaxWeight: 1000000,
        otherInventorySlots: 100,
        isShopInventory: false,
        inventory: "",
        showContextMenu: false,
        contextMenuPosition: { top: "0px", left: "0px" },
        contextMenuItem: null,
        showSubmenu: false,
        showHotbar: false,
        hotbarItems: [],
        showNotification: false,
        notificationText: "",
        notificationImage: "",
        notificationType: "added",
        notificationAmount: 1,
        showRequiredItems: false,
        requiredItems: [],
        selectedWeapon: null,
        showWeaponAttachments: false,
        selectedWeaponAttachments: [],
        currentlyDraggingItem: null,
        currentlyDraggingSlot: null,
        dragStartX: 0,
        dragStartY: 0,
        ghostElement: null,
        dragStartInventoryType: "player",
        transferAmount: null,
        notificationTimeout: null,
        showGiveSubmenu: false,
        showSubmenu: false,
        nearbyPlayers: [],
        isLoadingNearbyPlayers: false,
        activeGiveTargetId: null,
        giveAmount: 1,
        activeDropTarget: false,
        dropAmount: 1,
        serverTime: null,
        clientTimeOnSync: null,
        isAttachmentPanelOpen: false,
        selectedWeaponForPanel: null,
        selectedWeaponAttachmentsForPanel: [],
        isBlurEnabled: true,
      };
    },
    openInventory(data) {
      if (this.showHotbar) {
        this.toggleHotbar(false);
      }

      this.isInventoryOpen = true;
      this.maxWeight = data.maxweight;
      this.totalSlots = data.slots;
      this.playerInventory = {};
      this.otherInventory = {};

      if (data.inventory) {
        const items = Array.isArray(data.inventory)
          ? data.inventory
          : Object.values(data.inventory);
        items.forEach((item) => {
          if (item && item.slot) {
            this.playerInventory[item.slot] = item;
          }
        });
      }

      if (data.other) {
        if (data.other.inventory) {
          const otherItems = Array.isArray(data.other.inventory)
            ? data.other.inventory
            : Object.values(data.other.inventory);
          otherItems.forEach((item) => {
            if (item && item.slot) {
              this.otherInventory[item.slot] = item;
            }
          });
        }

        this.otherInventoryName = data.other.name;
        this.otherInventoryLabel = data.other.label;
        this.otherInventoryMaxWeight = data.other.maxweight;
        this.otherInventorySlots = data.other.slots;
        this.isShopInventory = this.otherInventoryName.startsWith("shop-");
        this.isOtherInventoryEmpty = false;
      } else {
        this.otherInventoryName = "ground";
        this.otherInventoryLabel = "Ground";
        this.otherInventoryMaxWeight = 1000000;
        this.otherInventorySlots = 40;
        this.isShopInventory = false;
        this.isOtherInventoryEmpty = true;
      }
      const savedBlurPreference = localStorage.getItem(
        "inventory_blur_enabled"
      );
      this.isBlurEnabled = savedBlurPreference !== "false";
      axios.post("https://qb-inventory/SetBlur", {
        enabled: this.isBlurEnabled,
      });
    },
    updateInventory(data) {
      this.playerInventory = {};
      if (data.inventory) {
        const items = Array.isArray(data.inventory)
          ? data.inventory
          : Object.values(data.inventory);
        items.forEach((item) => {
          if (item && item.slot) {
            this.playerInventory[item.slot] = item;
          }
        });
      }
    },
    async closeInventory() {
      this.clearDragData();
      let inventoryName = this.otherInventoryName;
      Object.assign(this, this.getInitialState());
      try {
        await axios.post("https://qb-inventory/CloseInventory", {
          name: inventoryName,
        });
      } catch (error) {
        console.error("Error closing inventory:", error);
      }
    },
    clearTransferAmount() {
      this.transferAmount = null;
    },
    getItemInSlot(slot, inventoryType) {
      if (inventoryType === "player") {
        return this.playerInventory[slot] || null;
      } else if (inventoryType === "other") {
        return this.otherInventory[slot] || null;
      }
      return null;
    },
    getHotbarItemInSlot(slot) {
      return this.hotbarItems[slot - 1] || null;
    },
    containerMouseDownAction(event) {
      if (!this.$el || typeof this.$el.querySelector !== "function") {
        return;
      }
      const contextMenu = this.$el.querySelector(".context-menu");
      if (contextMenu && !contextMenu.contains(event.target)) {
        this.showContextMenu = false;
        this.showSubmenu = false;
        this.activeDropTarget = false;
        this.activeGiveTargetId = null;
        this.dropAmount = 1;
      } else if (this.showContextMenu && event.button === 0) {
      }
    },
    handleMouseDown(event, slot, inventory) {
      if (event.button === 1) return;
      event.preventDefault();
      const itemInSlot = this.getItemInSlot(slot, inventory);
      if (event.button === 0) {
        if (event.shiftKey && itemInSlot) {
          this.splitAndPlaceItem(itemInSlot, inventory);
        } else {
          this.startDrag(event, slot, inventory);
        }
      } else if (event.button === 2 && itemInSlot) {
        if (this.otherInventoryName.startsWith("shop-")) {
          this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
          return;
        }
        if (this.otherInventoryName !== "ground") {
          this.moveItemBetweenInventories(itemInSlot, inventory);
        } else {
          this.showContextMenuOptions(event, itemInSlot);
        }
      }
    },
    moveItemBetweenInventories(item, sourceInventoryType) {
      const sourceInventory =
        sourceInventoryType === "player"
          ? this.playerInventory
          : this.otherInventory;
      const targetInventory =
        sourceInventoryType === "player"
          ? this.otherInventory
          : this.playerInventory;
      const targetWeight =
        sourceInventoryType === "player"
          ? this.otherInventoryWeight
          : this.playerWeight;
      const maxTargetWeight =
        sourceInventoryType === "player"
          ? this.otherInventoryMaxWeight
          : this.maxWeight;
      const amountToTransfer =
        this.transferAmount !== null ? this.transferAmount : 1;
      let targetSlot = null;

      const sourceItem = sourceInventory[item.slot];
      if (!sourceItem || sourceItem.amount < amountToTransfer) {
        this.inventoryError(item.slot);
        return;
      }

      const totalWeightAfterTransfer =
        targetWeight + sourceItem.weight * amountToTransfer;
      if (totalWeightAfterTransfer > maxTargetWeight) {
        this.inventoryError(item.slot);
        return;
      }

      if (item.unique) {
        targetSlot = this.findNextAvailableSlot(targetInventory);
        if (targetSlot === null) {
          this.inventoryError(item.slot);
          return;
        }

        const newItem = {
          ...item,
          inventory: sourceInventoryType === "player" ? "other" : "player",
          amount: amountToTransfer,
        };
        targetInventory[targetSlot] = newItem;
        newItem.slot = targetSlot;
      } else {
        const targetItemKey = Object.keys(targetInventory).find(
          (key) =>
            targetInventory[key] && targetInventory[key].name === item.name
        );
        const targetItem = targetInventory[targetItemKey];

        if (!targetItem) {
          const newItem = {
            ...item,
            inventory: sourceInventoryType === "player" ? "other" : "player",
            amount: amountToTransfer,
          };

          targetSlot = this.findNextAvailableSlot(targetInventory);
          if (targetSlot === null) {
            this.inventoryError(item.slot);
            return;
          }

          targetInventory[targetSlot] = newItem;
          newItem.slot = targetSlot;
        } else {
          targetItem.amount += amountToTransfer;
          targetSlot = targetItem.slot;
        }
      }

      sourceItem.amount -= amountToTransfer;

      if (sourceItem.amount <= 0) {
        delete sourceInventory[item.slot];
      }

      this.postInventoryData(
        sourceInventoryType,
        sourceInventoryType === "player" ? "other" : "player",
        item.slot,
        targetSlot,
        sourceItem.amount,
        amountToTransfer
      );
    },
    startDrag(event, slot, inventoryType) {
      event.preventDefault();
      const item = this.getItemInSlot(slot, inventoryType);
      if (!item) return;
      const slotElement = event.target.closest(".item-slot");
      if (!slotElement) return;
      this.dragStartX = event.clientX;
      this.dragStartY = event.clientY;
      const ghostElement = this.createGhostElement(slotElement);
      document.body.appendChild(ghostElement);
      const rect = slotElement.getBoundingClientRect();
      this.dragOffsetX = event.clientX - rect.left;
      this.dragOffsetY = event.clientY - rect.top;
      const initialX = event.clientX - this.dragOffsetX;
      const initialY = event.clientY - this.dragOffsetY;
      ghostElement.style.transform = `translate(${initialX}px, ${initialY}px)`;
      this.ghostElement = ghostElement;
      this.currentlyDraggingItem = item;
      this.currentlyDraggingSlot = slot;
      this.dragStartInventoryType = inventoryType;
      this.showContextMenu = false;
    },

    createGhostElement(slotElement) {
      const ghostElement = slotElement.cloneNode(true);
      const rect = slotElement.getBoundingClientRect();

      ghostElement.style.position = "absolute";
      ghostElement.style.pointerEvents = "none";
      ghostElement.style.opacity = "0.7";
      ghostElement.style.zIndex = "1000";

      ghostElement.style.top = "0";
      ghostElement.style.left = "0";

      ghostElement.style.width = `${rect.width}px`;
      ghostElement.style.height = `${rect.height}px`;
      ghostElement.style.paddingTop = "0";
      ghostElement.style.boxSizing = "border-box";
      ghostElement.classList.add("ghost-dragging");

      return ghostElement;
    },

    drag(event) {
      if (!this.currentlyDraggingItem || !this.ghostElement) return;
      const newX = event.clientX - this.dragOffsetX;
      const newY = event.clientY - this.dragOffsetY;
      this.ghostElement.style.transform = `translate(${newX}px, ${newY}px)`;
    },
    endDrag(event) {
      if (!this.currentlyDraggingItem) return;
      const elementsUnderCursor = document.elementsFromPoint(
        event.clientX,
        event.clientY
      );
      const playerSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList.contains("item-slot") &&
          el.closest(".player-inventory-section")
      );
      const otherSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList.contains("item-slot") &&
          el.closest(".other-inventory-section")
      );
      const dropZoneElement = elementsUnderCursor.find(
        (el) =>
          el.classList.contains("drop-zone-container") ||
          el.closest(".drop-zone-container")
      );
      if (playerSlotElement) {
        const targetSlot = Number(playerSlotElement.dataset.slot);
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === "player"
          )
        ) {
          this.handleDropOnPlayerSlot(targetSlot);
        }
      } else if (dropZoneElement) {
        this.handleDropOnGround();
      } else if (otherSlotElement) {
        const targetSlot = Number(otherSlotElement.dataset.slot);
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === "other"
          )
        ) {
          this.handleDropOnOtherSlot(targetSlot);
        }
      }

      this.clearDragData();
    },
    handleDropOnPlayerSlot(targetSlot) {
      if (this.isShopInventory && this.dragStartInventoryType === "other") {
        const { currentlyDraggingSlot, currentlyDraggingItem } = this;
        const targetInventory = this.getInventoryByType("player");
        const targetItem = targetInventory[targetSlot];

        if (
          (targetItem && targetItem.name !== currentlyDraggingItem.name) ||
          (targetItem &&
            targetItem.name === currentlyDraggingItem.name &&
            currentlyDraggingItem.unique)
        ) {
          this.inventoryError(currentlyDraggingSlot);
          return;
        }

        const amountToPurchase =
          this.transferAmount !== null ? this.transferAmount : 1;

        this.handlePurchase(
          targetSlot,
          currentlyDraggingSlot,
          currentlyDraggingItem,
          amountToPurchase
        );
      } else {
        this.handleItemDrop("player", targetSlot);
      }
    },
    handleDropOnOtherSlot(targetSlot) {
      if (this.otherInventoryName === "ground") {
        this.handleDropOnGround();
      } else {
        this.handleItemDrop("other", targetSlot);
      }
    },
    async handleDropOnGround() {
      const amountToDrop =
        this.transferAmount || this.currentlyDraggingItem.amount;
      const newItem = {
        ...this.currentlyDraggingItem,
        amount:
          amountToDrop > this.currentlyDraggingItem.amount
            ? this.currentlyDraggingItem.amount
            : amountToDrop,
        slot: 1,
        inventory: "other",
      };
      const draggingItem = this.currentlyDraggingItem;

      try {
        const response = await axios.post(
          "https://qb-inventory/DropItemFromUI",
          { ...newItem, fromSlot: this.currentlyDraggingSlot }
        );
        if (response.data && typeof response.data === "object") {
          const dropData = response.data;
          const remainingAmount = draggingItem.amount - newItem.amount;

          if (remainingAmount <= 0) {
            delete this.playerInventory[draggingItem.slot];
          } else {
            this.playerInventory[draggingItem.slot].amount = remainingAmount;
          }
          this.otherInventory = { 1: newItem };
          this.otherInventoryName = dropData.name;
          this.otherInventoryLabel = dropData.label;
          this.otherInventoryMaxWeight = dropData.maxweight;
          this.otherInventorySlots = dropData.slots;

          this.isOtherInventoryEmpty = false;
        } else {
          this.inventoryError(this.currentlyDraggingSlot);
        }
      } catch (error) {
        console.error("Error dropping item:", error);
        this.inventoryError(this.currentlyDraggingSlot);
      } finally {
        this.clearDragData();
        this.clearTransferAmount();
      }
    },
    clearDragData() {
      if (this.ghostElement) {
        document.body.removeChild(this.ghostElement);
        this.ghostElement = null;
      }
      this.currentlyDraggingItem = null;
      this.currentlyDraggingSlot = null;
    },
    getInventoryByType(inventoryType) {
      return inventoryType === "player"
        ? this.playerInventory
        : this.otherInventory;
    },
    handleItemDrop(targetInventoryType, targetSlot) {
      try {
        if (
          this.dragStartInventoryType === "other" &&
          targetInventoryType === "other" &&
          this.isShopInventory
        ) {
          return;
        }

        const sourceInventory = this.getInventoryByType(
          this.dragStartInventoryType
        );
        const targetInventory = this.getInventoryByType(targetInventoryType);
        const sourceItem = sourceInventory[this.currentlyDraggingSlot];
        if (!sourceItem) throw new Error("No item in source slot");

        const amountToTransfer =
          this.transferAmount !== null
            ? this.transferAmount
            : sourceItem.amount;
        if (sourceItem.amount < amountToTransfer)
          throw new Error("Insufficient amount");

        const targetWeight =
          targetInventoryType === "player"
            ? this.playerWeight
            : this.otherInventoryWeight;
        const maxTargetWeight =
          targetInventoryType === "player"
            ? this.maxWeight
            : this.otherInventoryMaxWeight;

        if (targetInventoryType !== this.dragStartInventoryType) {
          if (
            targetWeight + sourceItem.weight * amountToTransfer >
            maxTargetWeight
          ) {
            throw new Error("Not enough weight capacity");
          }
        }

        const targetItem = targetInventory[targetSlot];

        if (targetItem && sourceItem.name === targetItem.name) {
          const sourceHasExpiry = sourceItem.info && sourceItem.info.expiryDate;
          const targetHasExpiry = targetItem.info && targetItem.info.expiryDate;

          if (
            sourceHasExpiry &&
            targetHasExpiry &&
            sourceItem.info.expiryDate !== targetItem.info.expiryDate
          ) {
            sourceInventory[this.currentlyDraggingSlot] = targetItem;
            targetInventory[targetSlot] = sourceItem;
            sourceInventory[this.currentlyDraggingSlot].slot =
              this.currentlyDraggingSlot;
            targetInventory[targetSlot].slot = targetSlot;
            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlot,
              sourceItem.amount,
              targetItem.amount
            );

            this.clearDragData();
            this.clearTransferAmount();
            return;
          }
        }

        if (targetItem) {
          if (
            sourceItem.name === targetItem.name &&
            (targetItem.unique || sourceItem.unique)
          ) {
            this.inventoryError(this.currentlyDraggingSlot);
            return;
          }
          if (sourceItem.name === targetItem.name) {
            const originalAmount = sourceItem.amount;
            targetItem.amount += amountToTransfer;
            sourceItem.amount -= amountToTransfer;
            if (sourceItem.amount <= 0) {
              delete sourceInventory[this.currentlyDraggingSlot];
            }
            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlot,
              originalAmount,
              amountToTransfer
            );
          } else {
            sourceInventory[this.currentlyDraggingSlot] = targetItem;
            targetInventory[targetSlot] = sourceItem;
            sourceInventory[this.currentlyDraggingSlot].slot =
              this.currentlyDraggingSlot;
            targetInventory[targetSlot].slot = targetSlot;
            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlot,
              sourceItem.amount,
              targetItem.amount
            );
          }
        } else {
          const originalAmount = sourceItem.amount;
          const remainingAmount = sourceItem.amount - amountToTransfer;

          targetInventory[targetSlot] = {
            ...sourceItem,
            amount: amountToTransfer,
            slot: targetSlot,
          };

          if (remainingAmount <= 0) {
            delete sourceInventory[this.currentlyDraggingSlot];
          } else {
            sourceItem.amount = remainingAmount;
          }

          this.postInventoryData(
            this.dragStartInventoryType,
            targetInventoryType,
            this.currentlyDraggingSlot,
            targetSlot,
            originalAmount,
            amountToTransfer
          );
        }
      } catch (error) {
        console.error(error.message);
        this.inventoryError(this.currentlyDraggingSlot);
      } finally {
        this.clearDragData();
        this.clearTransferAmount();
      }
    },
    async handlePurchase(targetSlot, sourceSlot, sourceItem, transferAmount) {
      try {
        const response = await axios.post(
          "https://qb-inventory/AttemptPurchase",
          {
            item: sourceItem,
            amount: transferAmount || sourceItem.amount,
            shop: this.otherInventoryName,
          }
        );

        if (response.data) {
          const sourceInventory = this.getInventoryByType("other");
          const amountToTransfer =
            transferAmount !== null ? transferAmount : sourceItem.amount;

          if (sourceItem.amount < amountToTransfer) {
            this.inventoryError(sourceSlot);
            return;
          }

          sourceItem.amount -= amountToTransfer;
          if (sourceItem.amount <= 0) {
            delete sourceInventory[sourceSlot];
          }
        } else {
          this.inventoryError(sourceSlot);
        }
      } catch (error) {
        this.inventoryError(sourceSlot);
      }
    },
    async dropItem(item, quantity) {
      if (!item || !quantity || quantity <= 0) {
        this.showContextMenu = false;
        return;
      }

      const playerItemSlot = Object.keys(this.playerInventory).find(
        (key) => this.playerInventory[key] === item
      );
      if (playerItemSlot) {
        const amountToDrop = Math.floor(quantity);

        if (amountToDrop > item.amount) {
          console.error("Attempted to drop more items than available.");
          this.showContextMenu = false;
          return;
        }

        const newItem = {
          ...item,
          amount: amountToDrop,
        };

        try {
          const response = await axios.post(
            "https://qb-inventory/DropItemFromUI",
            {
              ...newItem,
              fromSlot: item.slot,
            }
          );

          if (response.data && typeof response.data === "object") {
            const dropData = response.data;
            const remainingAmount =
              this.playerInventory[playerItemSlot].amount - amountToDrop;

            if (remainingAmount <= 0) {
              delete this.playerInventory[playerItemSlot];
            } else {
              this.playerInventory[playerItemSlot].amount = remainingAmount;
            }

            this.showItemNotification({
              item: item,
              type: "remove",
              amount: amountToDrop,
            });
            this.otherInventory = { 1: newItem };
            this.otherInventoryName = dropData.name;
            this.otherInventoryLabel = dropData.label;
            this.otherInventoryMaxWeight = dropData.maxweight;
            this.otherInventorySlots = dropData.slots;
            this.isOtherInventoryEmpty = false;
            this.dropAmount = 1;
          }
        } catch (error) {
          this.inventoryError(item.slot);
        }
      }
      this.showContextMenu = false;
      this.activeDropTarget = false;
    },
    async useItem(item) {
      if (!item || item.useable === false) {
        return;
      }
      const playerItemKey = Object.keys(this.playerInventory).find(
        (key) =>
          this.playerInventory[key] &&
          this.playerInventory[key].slot === item.slot
      );
      if (playerItemKey) {
        try {
          await axios.post("https://qb-inventory/UseItem", {
            inventory: "player",
            item: item,
          });
          if (item.shouldClose) {
            this.closeInventory();
          }
        } catch (error) {
          console.error("Error using the item: ", error);
        }
      }
      this.showContextMenu = false;
    },
    showContextMenuOptions(event, item) {
      event.preventDefault();
      this.dropAmount = 1;
      if (
        this.contextMenuItem &&
        this.contextMenuItem.name === item.name &&
        this.showContextMenu
      ) {
        this.showContextMenu = false;
        this.contextMenuItem = null;
      } else {
        if (item.inventory === "other") {
          const matchingItemKey = Object.keys(this.playerInventory).find(
            (key) => this.playerInventory[key].name === item.name
          );
          const matchingItem = this.playerInventory[matchingItemKey];

          if (matchingItem && matchingItem.unique) {
            const newItemKey = Object.keys(this.playerInventory).length + 1;
            const newItem = {
              ...item,
              inventory: "player",
              amount: 1,
            };
            this.playerInventory[newItemKey] = newItem;
          } else if (matchingItem) {
            matchingItem.amount++;
          } else {
            const newItemKey = Object.keys(this.playerInventory).length + 1;
            const newItem = {
              ...item,
              inventory: "player",
              amount: 1,
            };
            this.playerInventory[newItemKey] = newItem;
          }
          item.amount--;

          if (item.amount <= 0) {
            const itemKey = Object.keys(this.otherInventory).find(
              (key) => this.otherInventory[key] === item
            );
            if (itemKey) {
              delete this.otherInventory[itemKey];
            }
          }
        }
        const menuLeft = event.clientX;
        const menuTop = event.clientY;
        this.showContextMenu = true;
        this.contextMenuPosition = {
          top: `${menuTop}px`,
          left: `${menuLeft}px`,
        };
        this.contextMenuItem = item;
      }
    },
    async openGiveMenu() {
      this.nearbyPlayers = [];
      this.isLoadingNearbyPlayers = true;
      this.showSubmenu = false;

      try {
        const response = await axios.post(
          "https://qb-inventory/GetNearbyPlayers",
          {}
        );
        if (response.data) {
          this.nearbyPlayers = response.data;
        }
      } catch (error) {
        console.error("Failed to get nearby players:", error);
        this.nearbyPlayers = [];
      } finally {
        this.isLoadingNearbyPlayers = false;
        this.$nextTick(() => {
          this.showSubmenu = true;
        });
      }
    },
    async giveItemToPlayer(targetId, amount) {
      if (!this.contextMenuItem || !amount || amount <= 0) return;

      const item = this.contextMenuItem;
      const amountToGive = Math.floor(amount);

      if (amountToGive > item.amount) {
        console.error("Attempted to give more items than available.");
        return;
      }

      try {
        const response = await axios.post(
          "https://qb-inventory/GiveItemToTarget",
          {
            targetId: targetId,
            item: item,
            amount: amountToGive,
            slot: item.slot,
            info: item.info,
          }
        );

        if (response.data) {
          this.playerInventory[item.slot].amount -= amountToGive;
          if (this.playerInventory[item.slot].amount <= 0) {
            delete this.playerInventory[item.slot];
          }
        }
      } catch (error) {
        console.error("Error giving item:", error);
      }
      this.showContextMenu = false;
      this.showSubmenu = false;
      this.nearbyPlayers = [];
      this.activeGiveTargetId = null;
    },
    findNextAvailableSlot(inventory) {
      for (let slot = 1; slot <= this.totalSlots; slot++) {
        if (!inventory[slot]) {
          return slot;
        }
      }
      return null;
    },
    splitAndPlaceItem(item, inventoryType) {
      const inventoryRef =
        inventoryType === "player" ? this.playerInventory : this.otherInventory;
      if (item && item.amount > 1) {
        const originalSlot = Object.keys(inventoryRef).find(
          (key) => inventoryRef[key] === item
        );
        if (originalSlot !== undefined) {
          const originalAmount = item.amount;
          const newItemAmount = Math.ceil(item.amount / 2);
          const oldItemAmount = Math.floor(item.amount / 2);

          const newItem = { ...item, amount: newItemAmount };
          const nextSlot = this.findNextAvailableSlot(inventoryRef);

          if (nextSlot !== null) {
            inventoryRef[nextSlot] = newItem;
            inventoryRef[nextSlot].slot = nextSlot;
            inventoryRef[originalSlot] = { ...item, amount: oldItemAmount };

            this.postInventoryData(
              inventoryType,
              inventoryType,
              originalSlot,
              nextSlot,
              originalAmount,
              newItemAmount
            );
          }
        }
      }
      this.showContextMenu = false;
    },
    toggleHotbar(data) {
      if (data.open) {
        this.hotbarItems = data.items;
        this.showHotbar = true;
      } else {
        this.showHotbar = false;
        this.hotbarItems = [];
      }
    },
    showItemNotification(data) {
      if (!data || !data.item) {
        console.error("Invalid data received for item notification");
        return;
      }

      const item = data.item;
      const type = data.type;
      const amount = data.amount || 1;
      this.notificationText = item.label || "Unknown Item";
      this.notificationImage = item.image ? `images/${item.image}` : null;

      let titleText = "";
      switch (type) {
        case "add":
          titleText = "RECEIVED";
          break;
        case "use":
          titleText = "USED";
          break;
        case "remove":
          titleText = "REMOVED";
          break;
        default:
          titleText = "INFO";
      }
      this.notificationType = `${titleText} x${amount}`;
      if (this.notificationTimeout) {
        clearTimeout(this.notificationTimeout);
      }
      this.showNotification = true;
      this.notificationTimeout = setTimeout(() => {
        this.showNotification = false;
      }, 3000);
    },
    showRequiredItem(data) {
      if (data.toggle) {
        this.requiredItems = data.items;
        this.showRequiredItems = true;
      } else {
        setTimeout(() => {
          this.showRequiredItems = false;
          this.requiredItems = [];
        }, 100);
      }
    },
    inventoryError(slot) {
      const slotElement = document.getElementById(`slot-${slot}`);
      if (slotElement) {
        slotElement.style.backgroundColor = "red";
      }
      axios.post("https://qb-inventory/PlayDropFail", {}).catch((error) => {
        console.error("Error playing drop fail:", error);
      });
      setTimeout(() => {
        if (slotElement) {
          slotElement.style.backgroundColor = "";
        }
      }, 1000);
    },
    copySerial() {
      if (!this.contextMenuItem) {
        return;
      }
      const item = this.contextMenuItem;
      if (item) {
        const el = document.createElement("textarea");
        el.value = item.info.serie;
        document.body.appendChild(el);
        el.select();
        document.execCommand("copy");
        document.body.removeChild(el);
      }
    },
    async openWeaponAttachments() {
      if (!this.contextMenuItem) return;
      this.showContextMenu = false;
      if (
        this.isAttachmentPanelOpen &&
        this.selectedWeaponForPanel === this.contextMenuItem
      ) {
        this.closeAttachmentPanel();
        return;
      }
      this.isAttachmentPanelOpen = true;
      this.selectedWeaponForPanel = this.contextMenuItem;
      this.selectedWeaponAttachmentsForPanel = [];

      try {
        const response = await axios.post(
          "https://qb-inventory/GetWeaponData",
          {
            weapon: this.selectedWeaponForPanel.name,
            ItemData: this.selectedWeaponForPanel,
          }
        );

        if (response.data && response.data.AttachmentData) {
          this.selectedWeaponAttachmentsForPanel = response.data.AttachmentData;
        }
      } catch (error) {
        console.error("Failed to get weapon attachments:", error);
        this.closeAttachmentPanel();
      }
    },
    closeAttachmentPanel() {
      this.isAttachmentPanelOpen = false;
      this.selectedWeaponForPanel = null;
      this.selectedWeaponAttachmentsForPanel = [];
    },
    async removeAttachment(attachment) {
      if (!this.selectedWeaponForPanel) return;

      try {
        const response = await axios.post(
          "https://qb-inventory/RemoveAttachment",
          {
            AttachmentData: attachment,
            WeaponData: this.selectedWeaponForPanel,
          }
        );
        this.selectedWeaponForPanel = response.data.WeaponData;
        this.selectedWeaponAttachmentsForPanel =
          response.data.Attachments || [];
        const nextSlot = this.findNextAvailableSlot(this.playerInventory);
        if (nextSlot !== null) {
          response.data.itemInfo.amount = 1;
          this.playerInventory[nextSlot] = response.data.itemInfo;
        }
      } catch (error) {
        console.error("Error removing attachment:", error);
      }
    },
    generateTooltipContent(item) {
      if (!item) {
        return "";
      }
      let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;
      const description =
        item.info && item.info.description
          ? item.info.description.replace(/\n/g, "<br>")
          : item.description
          ? item.description.replace(/\n/g, "<br>")
          : "No description available.";
      if (item.info && item.info.expiryDate) {
        content += `<div class="tooltip-info"><span class="tooltip-info-key">Freshness:</span> ${this.formatExpiryTime(
          item
        )}</div>`;
      }

      if (
        item.info &&
        Object.keys(item.info).length > 0 &&
        item.info.display !== false
      ) {
        for (const [key, value] of Object.entries(item.info)) {
          if (
            key !== "description" &&
            key !== "display" &&
            key !== "creationDate" &&
            key !== "expiryDate"
          ) {
            let valueStr = value;
            if (key === "attachments") {
              valueStr = Object.keys(value).length > 0 ? "true" : "false";
            }
            content += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(
              key
            )}:</span> ${valueStr}</div>`;
          }
        }
      }
      content += `<div class="tooltip-description">${description}</div>`;
      content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${
        item.weight !== undefined && item.weight !== null
          ? (item.weight / 1000).toFixed(1)
          : "N/A"
      }kg</div>`;
      content += `</div>`;
      return content;
    },
    formatKey(key) {
      return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
    },
    postInventoryData(
      fromInventory,
      toInventory,
      fromSlot,
      toSlot,
      fromAmount,
      toAmount
    ) {
      let fromInventoryName =
        fromInventory === "other" ? this.otherInventoryName : fromInventory;
      let toInventoryName =
        toInventory === "other" ? this.otherInventoryName : toInventory;

      axios
        .post("https://qb-inventory/SetInventoryData", {
          fromInventory: fromInventoryName,
          toInventory: toInventoryName,
          fromSlot,
          toSlot,
          fromAmount,
          toAmount,
        })
        .catch((error) => {
          console.error("Error posting inventory data:", error);
        });
    },
    handleGiveHover() {
      if (this.nearbyPlayers.length === 0 && !this.isLoadingNearbyPlayers) {
        this.isLoadingNearbyPlayers = true;
        this.showSubmenu = true;

        axios
          .post("https://qb-inventory/GetNearbyPlayers", {})
          .then((response) => {
            if (response.data) {
              this.nearbyPlayers = response.data;
            }
          })
          .catch((error) => {
            console.error("Failed to get nearby players:", error);
            this.nearbyPlayers = [];
          })
          .finally(() => {
            this.isLoadingNearbyPlayers = false;
          });
      } else {
        this.showSubmenu = true;
      }
    },
    handleGiveLeave() {
      this.showSubmenu = false;
      this.nearbyPlayers = [];
      this.isLoadingNearbyPlayers = false;
      this.activeGiveTargetId = null;
    },
    setActiveGiveTarget(playerId) {
      if (this.activeGiveTargetId === playerId) {
        this.activeGiveTargetId = null;
      } else {
        this.activeGiveTargetId = playerId;
        this.giveAmount = 1;
      }
    },

    clearActiveGiveTarget() {},

    validateGiveAmount() {
      if (!this.contextMenuItem) return;
      if (this.giveAmount > this.contextMenuItem.amount) {
        this.giveAmount = this.contextMenuItem.amount;
      }
      if (this.giveAmount < 1) {
        this.giveAmount = 1;
      }
    },
    setActiveDropTarget(isActive) {
      this.activeDropTarget = isActive;
    },

    validateDropAmount() {
      if (!this.contextMenuItem) return;
      if (this.dropAmount > this.contextMenuItem.amount) {
        this.dropAmount = this.contextMenuItem.amount;
      }
      if (this.dropAmount < 1 || !this.dropAmount) {
        this.dropAmount = 1;
      }
    },
    formatNumber(num) {
      if (num === null || num === undefined) return "";
      return num.toLocaleString("de-DE");
    },
    getCurrentServerTime() {
      if (!this.serverTime || !this.clientTimeOnSync) {
        return Math.floor(Date.now() / 1000);
      }
      const timeSinceSync = (Date.now() - this.clientTimeOnSync) / 1000;
      return Math.floor(this.serverTime + timeSinceSync);
    },

    getExpiryPercentage(item) {
      if (!item || !item.info || !item.info.expiryDate) {
        return 0;
      }
      const creationTime = item.info.creationDate;
      const expiryTime = item.info.expiryDate;
      const totalLifespan = expiryTime - creationTime;
      if (totalLifespan <= 0) {
        return 0;
      }
      const currentTime = this.getCurrentServerTime();
      const timeRemaining = expiryTime - currentTime;
      if (timeRemaining <= 0) {
        return 0;
      }
      const percentage = (timeRemaining / totalLifespan) * 100;
      return Math.max(0, Math.min(100, percentage));
    },

    isItemExpired(item) {
      if (!item || !item.info || !item.info.expiryDate) {
        return false;
      }

      const currentTime = this.getCurrentServerTime();
      return currentTime >= item.info.expiryDate;
    },

    formatExpiryTime(item) {
      if (
        !item ||
        !item.info ||
        !item.info.expiryDate ||
        this.isItemExpired(item)
      ) {
        return '<span style="color: var(--error);">Expired</span>';
      }

      const currentTime = this.getCurrentServerTime();
      const timeRemaining = item.info.expiryDate - currentTime;

      const days = Math.floor(timeRemaining / 86400);
      const hours = Math.floor((timeRemaining % 86400) / 3600);
      const minutes = Math.floor((timeRemaining % 3600) / 60);

      if (days > 0) {
        return `${days}d ${hours}h remaining`;
      } else if (hours > 0) {
        return `${hours}h ${minutes}m remaining`;
      } else {
        return `${minutes}m remaining`;
      }
    },
    getAttachmentByType(type) {
      if (
        !this.selectedWeaponAttachmentsForPanel ||
        this.selectedWeaponAttachmentsForPanel.length === 0
      ) {
        return null;
      }
      return (
        this.selectedWeaponAttachmentsForPanel.find((att) =>
          att.attachment.toLowerCase().includes(type)
        ) || null
      );
    },

    getAttachmentTooltip(type) {
      const attachment = this.getAttachmentByType(type);
      if (attachment) {
        return `Detach ${attachment.label}`;
      }
      return "Empty Slot";
    },
    toggleBlur() {
      this.isBlurEnabled = !this.isBlurEnabled;
      localStorage.setItem("inventory_blur_enabled", this.isBlurEnabled);
      axios
        .post("https://qb-inventory/ToggleBlur", {
          enabled: this.isBlurEnabled,
        })
        .catch((err) => console.error("Failed to toggle blur", err));
    },
  },
  mounted() {
    window.addEventListener("keydown", (event) => {
      const key = event.key;
      if (key === "Escape" || key === "Tab") {
        if (this.isInventoryOpen) {
          this.closeInventory();
        }
      }
    });

    window.addEventListener("message", (event) => {
      const { action, ...data } = event.data;
      switch (action) {
        case "open":
          this.openInventory(data);
          break;
        case "close":
          this.closeInventory();
          break;
        case "update":
          this.updateInventory(data);
          break;
        case "toggleHotbar":
          this.toggleHotbar(data);
          break;
        case "itemBox":
          this.showItemNotification(data);
          break;
        case "requiredItem":
          this.showRequiredItem(data);
          break;
        case "setServerTime":
          this.serverTime = data.serverTime;
          this.clientTimeOnSync = Date.now();
          break;
      }
    });
  },
  beforeUnmount() {
    window.removeEventListener("mousemove", () => {});
    window.removeEventListener("keydown", () => {});
    window.removeEventListener("message", () => {});
  },
});

InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");
