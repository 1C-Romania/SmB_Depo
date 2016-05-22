
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure forms the list of available batch statuses depending on FO and passed parameters.
//
Procedure SetListOfBatchStatuses()
	
	List = Items.Status.ChoiceList;
	List.Clear();
	
	UseStatuses = New Map;
	UseStatuses.Insert(Enums.BatchStatuses.OwnInventory, True);
	UseStatuses.Insert(Enums.BatchStatuses.ProductsOnCommission, Constants.FunctionalOptionReceiveGoodsOnCommission.Get());
	UseStatuses.Insert(Enums.BatchStatuses.CommissionMaterials, Constants.FunctionalOptionTolling.Get());
	UseStatuses.Insert(Enums.BatchStatuses.SafeCustody, Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get());
	
	BatchStatusRestriction = Undefined;
	If Not Parameters.FillingValues.Property("Status", BatchStatusRestriction) Then
		Parameters.AdditionalParameters.Property("StatusRestriction", BatchStatusRestriction);
	EndIf;
	
	If BatchStatusRestriction = Undefined Then
		
		For Each KeyAndValue IN UseStatuses Do
			If KeyAndValue.Value = True Then
				List.Add(KeyAndValue.Key);
			EndIf;
		EndDo;
		
	Else
		
		If (TypeOf(BatchStatusRestriction) = Type("Array") Or TypeOf(BatchStatusRestriction) = Type("FixedArray")) 
			AND BatchStatusRestriction.Count() > 0 Then
			
			For Each Type IN BatchStatusRestriction Do
				If UseStatuses.Get(Type) <> False Then
					List.Add(Type);
				EndIf;
			EndDo;
			
		ElsIf TypeOf(BatchStatusRestriction) = Type("EnumRef.BatchStatuses") Then
			
			If UseStatuses.Get(BatchStatusRestriction) <> False Then
				List.Add(BatchStatusRestriction);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetListOfBatchStatuses()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Owner) AND 
		Not Object.Owner.UseBatches Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Products and services are not accounted by batches!
							|Select the ""Use batches"" check box in the products and services card'");
		Message.Message();
		Cancel = True;
		
	EndIf;
	
	// Available status list.
	SetListOfBatchStatuses();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure // BeforeWriteAtServer()

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion


