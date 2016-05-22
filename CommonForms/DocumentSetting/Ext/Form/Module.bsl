////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure write user settings in register.
//
Procedure SetSetting(SettingName)	
	
	User = Users.CurrentUser();
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();
	
	RecordSet.Filter.User.Use = True;
	RecordSet.Filter.User.Value	  = User;
	RecordSet.Filter.Setting.Use	  = True;
	RecordSet.Filter.Setting.Value		  = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	
	Record = RecordSet.Add();
	
	Record.User = User;
	Record.Setting    = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	Record.Value     = ChartsOfCharacteristicTypes.UserSettings[SettingName].ValueType.AdjustValue(ThisForm[SettingName]);
	
	RecordSet.Write();
	
EndProcedure // WriteNewSettings()

&AtServer
// Procedure write user settings in register.
//
Procedure WriteNewSettings()
	
	If ValueIsFilled(WorkKindPositionInJobOrder) Then
		SetSetting("WorkKindPositionInJobOrder");
	EndIf;
	If ValueIsFilled(WorkKindPositionInWorkTask) Then
		SetSetting("WorkKindPositionInWorkTask");
	EndIf;
	If ValueIsFilled(ShipmentDatePositionInCustomerOrder) Then
		SetSetting("ShipmentDatePositionInCustomerOrder");
	EndIf;
	If ValueIsFilled(ReceiptDatePositionInPurchaseOrder) Then
		SetSetting("ReceiptDatePositionInPurchaseOrder");
	EndIf;
	If ValueIsFilled(CustomerOrderPositionInShipmentDocuments) Then
		SetSetting("CustomerOrderPositionInShipmentDocuments");
	EndIf;
	If ValueIsFilled(CustomerOrderPositionInInventoryTransfer) Then
		SetSetting("CustomerOrderPositionInInventoryTransfer");
	EndIf;
	If ValueIsFilled(PurchaseOrderPositionInReceiptDocuments) Then
		SetSetting("PurchaseOrderPositionInReceiptDocuments");
	EndIf;	 
	If ValueIsFilled(UseConsumerMaterialsInJobOrder) Then
		SetSetting("UseConsumerMaterialsInJobOrder");
	EndIf;	 
	If ValueIsFilled(UseProductsInJobOrder) Then
		SetSetting("UseProductsInJobOrder");
	EndIf;	 
	If ValueIsFilled(UseMaterialsInJobOrder) Then
		SetSetting("UseMaterialsInJobOrder");
	EndIf;
	If ValueIsFilled(UsePerformerSalariesInJobOrder) Then
		SetSetting("UsePerformerSalariesInJobOrder");
	EndIf;
	If ValueIsFilled(PositionAssignee) Then
		SetSetting("PositionAssignee");
	EndIf;
	If ValueIsFilled(PositionResponsible) Then
		SetSetting("PositionResponsible");
	EndIf;
	
	RefreshReusableValues();
	
EndProcedure // WriteNewSettings()

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified(StructureOfFormAttributes)

	WereMadeChanges = False;
	
	ChangesOfPositionOfWorkKindInJobOrder						= WorkKindPositionInJobOrderOnOpen <> WorkKindPositionInJobOrder;
	ChangesOfJobKindPositionInWorkTask					= JobKindPositionInWorkTaskOnOpen <> WorkKindPositionInWorkTask;
	ChangesOfShipmentDatePositionInCustomerOrder				= ShipmentDatePositionInCustomerOrderOnOpen <> ShipmentDatePositionInCustomerOrder;
	ChangesOfReceiptDatePositionInPurchaseOrder			= ReceiptDatePositionInPurchaseOrderOnOpen <> ReceiptDatePositionInPurchaseOrder;
	ChangesOfCustomerOrderPositionInShipmentDocuments		= CustomerOrderPositionInShipmentDocumentsOnOpen <> CustomerOrderPositionInShipmentDocuments;
	ChangesOfCustomerOrderPositionInInventoryTransfer		= CustomerOrderPositionInInventoryTransferOnOpen <> CustomerOrderPositionInInventoryTransfer;
	ChangesOfPurchaseOrderPositionInReceiptDocuments	= LocationOfSupplierOrderInIncomeDocumentsOnOpen <> PurchaseOrderPositionInReceiptDocuments;
	ChangesOfUseConsumerMaterialsInJobOrder			= UseConsumerMaterialsInJobOrderOnOpen <> UseConsumerMaterialsInJobOrder;
	ChangesOfUseGoodsInJobOrder						= UseGoodsInJobOrderOnOpen <> UseProductsInJobOrder;
	ChangesOfUseMaterialsInJobOrder					= UseMaterialsInJobOrderOnOpen <> UseMaterialsInJobOrder;
	ChangesOfUsePerformerSalariesInJobOrder		= UsePerformerSalariesInJobOrderOnOpen <> UsePerformerSalariesInJobOrder;
	ChangesOfPositionAssignee								= PositionAssigneeOnOpen <> PositionAssignee;
	ChangesOfPositionResponsible								= PositionResponsibleOnOpen <> PositionResponsible;
	
	If ChangesOfPositionOfWorkKindInJobOrder
	 OR ChangesOfJobKindPositionInWorkTask
	 OR ChangesOfShipmentDatePositionInCustomerOrder
	 OR ChangesOfReceiptDatePositionInPurchaseOrder
	 OR ChangesOfCustomerOrderPositionInShipmentDocuments
	 OR ChangesOfCustomerOrderPositionInInventoryTransfer
	 OR ChangesOfPurchaseOrderPositionInReceiptDocuments 
	 OR ChangesOfUseConsumerMaterialsInJobOrder
	 OR ChangesOfUseGoodsInJobOrder
	 OR ChangesOfUseMaterialsInJobOrder
	 OR ChangesOfUsePerformerSalariesInJobOrder
	 OR ChangesOfPositionAssignee
	 OR ChangesOfPositionResponsible Then
		
		WereMadeChanges = True;
		
	EndIf;
	
	StructureOfFormAttributes.Insert("WereMadeChanges",							 		WereMadeChanges);
	StructureOfFormAttributes.Insert("WorkKindPositionInJobOrder",					 		WorkKindPositionInJobOrder);
	StructureOfFormAttributes.Insert("WorkKindPositionInWorkTask",				 		WorkKindPositionInWorkTask);
	StructureOfFormAttributes.Insert("ShipmentDatePositionInCustomerOrder",			 		ShipmentDatePositionInCustomerOrder);
	StructureOfFormAttributes.Insert("ReceiptDatePositionInPurchaseOrder",		 		ReceiptDatePositionInPurchaseOrder);
	StructureOfFormAttributes.Insert("CustomerOrderPositionInShipmentDocuments",	 		CustomerOrderPositionInShipmentDocuments);
	StructureOfFormAttributes.Insert("CustomerOrderPositionInInventoryTransfer",	 		CustomerOrderPositionInInventoryTransfer);
	StructureOfFormAttributes.Insert("PurchaseOrderPositionInReceiptDocuments", 		PurchaseOrderPositionInReceiptDocuments);
	StructureOfFormAttributes.Insert("UseConsumerMaterialsInJobOrder",		 		UseConsumerMaterialsInJobOrder);
	StructureOfFormAttributes.Insert("UseProductsInJobOrder",					 		UseProductsInJobOrder);
	StructureOfFormAttributes.Insert("UseMaterialsInJobOrder",				 		UseMaterialsInJobOrder);
	StructureOfFormAttributes.Insert("UsePerformerSalariesInJobOrder",	 		UsePerformerSalariesInJobOrder);
	StructureOfFormAttributes.Insert("PositionResponsible",							 		PositionResponsible);
	StructureOfFormAttributes.Insert("PositionAssignee",							 		PositionAssignee);
	
EndProcedure // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WereMadeChanges = False;
	RememberSelection = False;
	
	If Parameters.Property("WorkKindPositionInJobOrder") Then
		WorkKindPositionInJobOrder = Parameters.WorkKindPositionInJobOrder;
		WorkKindPositionInJobOrderOnOpen = Parameters.WorkKindPositionInJobOrder;
		Items.GroupWorkKindPositionInJobOrder.Visible = True;
		Items.WorkKindPositionInJobOrder.Visible = True;
	Else
		Items.GroupWorkKindPositionInJobOrder.Visible = False;
		Items.WorkKindPositionInJobOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("WorkKindPositionInWorkTask") Then
		WorkKindPositionInWorkTask = Parameters.WorkKindPositionInWorkTask;
		JobKindPositionInWorkTaskOnOpen = Parameters.WorkKindPositionInWorkTask;
		Items.GroupPositionOfWorkKindInWorkTask.Visible = True;
		Items.WorkKindPositionInWorkTask.Visible = True;
	Else
		Items.GroupPositionOfWorkKindInWorkTask.Visible = False;
		Items.WorkKindPositionInWorkTask.Visible = False;
	EndIf;
	
	If Parameters.Property("ShipmentDatePositionInCustomerOrder") Then
		ShipmentDatePositionInCustomerOrder = Parameters.ShipmentDatePositionInCustomerOrder;
		ShipmentDatePositionInCustomerOrderOnOpen = Parameters.ShipmentDatePositionInCustomerOrder;
		Items.GroupShipmentDatePositionInCustomerOrder.Visible = True;
		Items.ShipmentDatePositionInCustomerOrder.Visible = True;
	Else
		Items.GroupShipmentDatePositionInCustomerOrder.Visible = False;
		Items.ShipmentDatePositionInCustomerOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("ReceiptDatePositionInPurchaseOrder") Then
		ReceiptDatePositionInPurchaseOrder = Parameters.ReceiptDatePositionInPurchaseOrder;
		ReceiptDatePositionInPurchaseOrderOnOpen = Parameters.ReceiptDatePositionInPurchaseOrder;
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = True;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = True;
	Else
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = False;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("CustomerOrderPositionInShipmentDocuments") Then
		CustomerOrderPositionInShipmentDocuments = Parameters.CustomerOrderPositionInShipmentDocuments;
		CustomerOrderPositionInShipmentDocumentsOnOpen = Parameters.CustomerOrderPositionInShipmentDocuments;
		Items.GroupCustomerOrderPositionInShipmentDocuments.Visible = True;
		Items.CustomerOrderPositionInShipmentDocuments.Visible = True;
	Else
		Items.GroupCustomerOrderPositionInShipmentDocuments.Visible = False;
		Items.CustomerOrderPositionInShipmentDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("CustomerOrderPositionInInventoryTransfer") Then
		CustomerOrderPositionInInventoryTransfer = Parameters.CustomerOrderPositionInInventoryTransfer;
		CustomerOrderPositionInInventoryTransferOnOpen = Parameters.CustomerOrderPositionInInventoryTransfer;
		Items.GroupCustomerOrderPositionInInventoryTransfer.Visible = True;
		Items.CustomerOrderPositionInInventoryTransfer.Visible = True;
	Else
		Items.GroupCustomerOrderPositionInInventoryTransfer.Visible = False;
		Items.CustomerOrderPositionInInventoryTransfer.Visible = False;
	EndIf;
	
	If Parameters.Property("PurchaseOrderPositionInReceiptDocuments") Then
		PurchaseOrderPositionInReceiptDocuments = Parameters.PurchaseOrderPositionInReceiptDocuments;
		LocationOfSupplierOrderInIncomeDocumentsOnOpen = Parameters.PurchaseOrderPositionInReceiptDocuments;
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = True;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = True;
	Else
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = False;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("UseConsumerMaterialsInJobOrder") Then
		UseConsumerMaterialsInJobOrder = Parameters.UseConsumerMaterialsInJobOrder;
		UseConsumerMaterialsInJobOrderOnOpen = Parameters.UseConsumerMaterialsInJobOrder;
		Items.GroupUseConsumerMaterialsInJobOrder.Visible = True;
		Items.UseConsumerMaterialsInJobOrder.Visible = True;
	Else
		Items.GroupUseConsumerMaterialsInJobOrder.Visible = False;
		Items.UseConsumerMaterialsInJobOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseProductsInJobOrder") Then
		UseProductsInJobOrder = Parameters.UseProductsInJobOrder;
		UseGoodsInJobOrderOnOpen = Parameters.UseProductsInJobOrder;
		Items.GroupUseProductsInJobOrder.Visible = True;
		Items.UseProductsInJobOrder.Visible = True;
	Else
		Items.GroupUseProductsInJobOrder.Visible = False;
		Items.UseProductsInJobOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseMaterialsInJobOrder") Then
		UseMaterialsInJobOrder = Parameters.UseMaterialsInJobOrder;
		UseMaterialsInJobOrderOnOpen = Parameters.UseMaterialsInJobOrder;
		Items.GroupUseMaterialsInJobOrder.Visible = True;
		Items.UseMaterialsInJobOrder.Visible = True;
	Else
		Items.GroupUseMaterialsInJobOrder.Visible = False;
		Items.UseMaterialsInJobOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UsePerformerSalariesInJobOrder") Then
		UsePerformerSalariesInJobOrder = Parameters.UsePerformerSalariesInJobOrder;
		UsePerformerSalariesInJobOrderOnOpen = Parameters.UsePerformerSalariesInJobOrder;
		Items.GroupUsePerformerSalariesInJobOrder.Visible = True;
		Items.UsePerformerSalariesInJobOrder.Visible = True;
	Else
		Items.GroupUsePerformerSalariesInJobOrder.Visible = False;
		Items.UsePerformerSalariesInJobOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionAssignee") Then
		PositionAssignee = Parameters.PositionAssignee;
		PositionAssigneeOnOpen = Parameters.PositionAssignee;
		Items.GroupPositionAssignee.Visible = True;
		Items.PositionAssignee.Visible = True;
	Else
		Items.GroupPositionAssignee.Visible = False;
		Items.PositionAssignee.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionResponsible") Then
		PositionResponsible = Parameters.PositionResponsible;
		LocationLocationResponsibleOnOpen = Parameters.PositionResponsible;
		Items.GroupPositionResponsible.Visible = True;
		Items.PositionResponsible.Visible = True;
	Else
		Items.GroupPositionResponsible.Visible = False;
		Items.PositionResponsible.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure OK(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	Close(StructureOfFormAttributes);
	
EndProcedure // CommandOK()

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure RememberSelection(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	WriteNewSettings();
	
	Close(StructureOfFormAttributes);
	
EndProcedure // RememberSelection()
