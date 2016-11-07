
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Function creates page on form.
//
Function CreatePage(PageName, Title, Parent, FormGroupType)

	NewItem = Items.Add(PageName, Type("FormGroup"), Parent);
	NewItem.Type                      = FormGroupType;
	NewItem.Title                = Title;
	NewItem.VerticalStretch   = True;
	NewItem.HorizontalStretch = True;

	Return NewItem;

EndFunction // CreatePage()

&AtServer
// Function creates the register page name.
//
Function GetRegisterPageName(RegisterName)

	Return "Page" + RegisterName;

EndFunction // GetRegisterPageName()

&AtServer
// Procedure deletes page on form following register.
//
Procedure DeleteRegisterPage(RegisterName)

	Items.Delete(Items.Find(GetRegisterPageName(RegisterName)));

EndProcedure // DeleteRegisterPage()

&AtServer
// Procedure creates table for register on form.
//
Procedure CreateRegisterTable(RegisterName, Columns, Parent)

	FormTable = Items.Add("RegisterRecordTable" + RegisterName, Type("FormTable"), Parent);
	FormTable.DataPath      = "Object.RegisterRecords." + RegisterName;
	Parent.TitleDataPath = FormTable.DataPath + ".RowsCount";

	For Each Column IN Columns Do

		If Column.Value <> Undefined Then
			
			FormField = Items.Add(FormTable.Name + Column.Key, Type("FormField"), FormTable);
			FormField.DataPath = FormTable.DataPath + "." + Column.Key;
			FormField.Title   = Column.Value;
			FormField.Type         = FormFieldType.InputField;
			
		EndIf;
	
	EndDo;

	FormTable.SetAction("OnStartEdit", "Attachable_TableOnStartEdit");
	
EndProcedure // CreateRegisterTable()

&AtServer
// Procedure renders the register table on the form page.
//
Procedure ShowRegisterTableOnPage(Val TSRow)

	If Metadata.AccumulationRegisters.Find(TSRow.Name) <> Undefined Then
		
		RegistersPage = Items.AccumulationRegistersSetting;
		PresentationRegister = Metadata.AccumulationRegisters[TSRow.Name].Synonym;
		
		Register = Metadata.AccumulationRegisters[TSRow.Name];
		
	ElsIf Metadata.InformationRegisters.Find(TSRow.Name) <> Undefined Then
		
		RegistersPage = Items.InformationRegistersSetting;
		PresentationRegister = Metadata.InformationRegisters[TSRow.Name].Synonym;
		
		Register = Metadata.InformationRegisters[TSRow.Name];
		
	Else
		
		Return;
		
	EndIf;
	
	StructureOfRegister = New Structure;
	StructureOfRegister.Insert("Period");
	StructureOfRegister.Insert("LineNumber");
	StructureOfRegister.Insert("Active");
	StructureOfRegister.Insert("RecordType");
	
	For Each StandardAttribute in Register.StandardAttributes Do
		If StructureOfRegister.Property(StandardAttribute.Name) Then
			StructureOfRegister[StandardAttribute.Name] = StandardAttribute.Synonym;
		EndIf;
	EndDo;
	
	For Each Dimension in Register.Dimensions Do
		StructureOfRegister.Insert(Dimension.Name, Dimension.Synonym);
	EndDo;
	
	For Each Resource in Register.Resources Do
		StructureOfRegister.Insert(Resource.Name, Resource.Synonym);
	EndDo;
	
	For Each Attribute in Register.Attributes Do
		StructureOfRegister.Insert(Attribute.Name, Attribute.Synonym);
	EndDo;
	
	PageForRegister = CreatePage(GetRegisterPageName(TSRow.Name), PresentationRegister, RegistersPage, 
										  FormGroupType.Page);
	
	CreateRegisterTable(TSRow.Name, StructureOfRegister, PageForRegister);
	
EndProcedure // ShowRegisterTableOnPage()

&AtServer
// Procedure renders registers on form.
//
Procedure ShowRegisters(RegistersTable)

	For Each String IN RegistersTable Do

		ShowRegisterTableOnPage(String);

	EndDo;

EndProcedure // ShowRegisters()

&AtServer
// Procedure is designed for for register adding/removing from list of editable registers.
//
Procedure ProcessRegistersChange(ListOfRegisters)

	For Each Item IN ListOfRegisters Do

		// It is necessary to add register.
		If Item.Check Then

			TSRow = Object.RegistersTable.Add();
			TSRow.Name           = Item.Value;

			ShowRegisterTableOnPage(TSRow);

		Else

			For Each String IN Object.RegistersTable.FindRows(New Structure("Name", Item.Value)) Do
				Object.RegistersTable.Delete(String);
			EndDo;

			Object.RegisterRecords[Item.Value].Clear();
			DeleteRegisterPage(Item.Value);

		EndIf;

	EndDo;

	Modified = True;

EndProcedure // ProcessRegistersChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed);
	
	ShowRegisters(Object.RegistersTable);
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("RegistersCorrectionPostingDocument");
	// End StandardSubsystems.PerformanceEstimation
	
EndProcedure // BeforeWrite()

// Attachable event handler "OnStartEdit" of the form table.
//
&AtClient
Procedure Attachable_TableOnStartEdit(Item, NewRow, Copy)

	If NewRow
		AND Item.CurrentData.Property("Currency") Then
		
		Item.CurrentData.Currency = AccountingCurrency;
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure is called when clicking button "Register content setting" of command form panel.
// 
Procedure RegistersContentSetting(Command)
	
	ListOfUsedRegisters = New ValueList;

	For Each String IN Object.RegistersTable Do
		ListOfUsedRegisters.Add(String.Name);
	EndDo;

	Result = Undefined;


	OpenForm("Document.RegistersCorrection.Form.RegisterChoiceForm",
				New Structure("ListOfUsedRegisters", ListOfUsedRegisters),,,,, New NotifyDescription("RegistersContentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure RegistersContentSettingEnd(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If TypeOf(Result) = Type("ValueList") Then
        
        ProcessRegistersChange(Result);
        
    EndIf;

EndProcedure // RegistersContentSetting()

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





// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
