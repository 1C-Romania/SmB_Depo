
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.ConfigureCharacteristicsPropertiesSet.Visible = GetFunctionalOption("UseAdditionalAttributesAndInformation")
															AND GetFunctionalOption("UseCharacteristics");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler Click of the hyperlink ConfigureCharacteristicsPropertiesSet.
//
Procedure ConfigureCharacteristicsPropertiesSetClick(Item)
	
	If Not ValueIsFilled(Object.SetOfCharacteristicProperties) Then
		
		QuestionText = NStr("en='Characteristic
		|property set edit is possible only after item record, write the item?';ru='Редактирование набора свойств характеристик
		|возможно только после записи элемента, записать элемент?'");
		
		Notification = New NotifyDescription("ConfigureSetOfPropertiesCharacteristicsClickEnd",ThisForm);
		ShowQueryBox(Notification,QuestionText, QuestionDialogMode.OKCancel,,DialogReturnCode.Cancel, NStr("en='Edit the characteristic property set';ru='Редактирование набора свойств характеристик'"));
		
		Return;
		
	EndIf;
	
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ObjectForm", New Structure("Key", Object.SetOfCharacteristicProperties));
	
EndProcedure // ConfigureCharacteristicsPropertiesSetClick()

&AtClient
Procedure ConfigureSetOfPropertiesCharacteristicsClickEnd(Response,Parameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ObjectForm", New Structure("Key", Object.SetOfCharacteristicProperties));
	
EndProcedure

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

#EndRegion















