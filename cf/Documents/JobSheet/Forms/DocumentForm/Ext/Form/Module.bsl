
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// Gets data set from server.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// Receives employee ID with the server.
//
Function GetTabNumber(Performer)
	
	Return Performer.Code;
	
EndFunction // GetCompanyDataOnChange()

&AtServer
// Procedure fills crew members.
//
Procedure FillCrewMembersAtServer()

	Document = FormAttributeToValue("Object");
	Document.FillCrewMembers();
	ValueToFormAttribute(Document, "Object");
	Modified = True;	

EndProcedure

&AtServerNoContext
// It receives data set from server to operation.
//
Function GetOperationData(StructureData)
	
	StructureData.Insert("TimeNorm", StructureData.ProductsAndServices.TimeNorm);
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("PriceKind", Catalogs.PriceKinds.Accounting);
	StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	StructureData.Insert("Factor", 1);
	StructureData.Insert("AmountIncludesVAT", Catalogs.PriceKinds.Accounting.PriceIncludesVAT);
	
	StructureData.Insert("Price", SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDuration()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.StandardHours = CurrentRow.TimeNorm * CurrentRow.QuantityFact;	
	
EndProcedure

&AtClient
// Procedure calculates operation performing cost.
//
// Parameters:
//  No.
//
Procedure CalculateCost()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Cost = CurrentRow.Tariff * CurrentRow.QuantityFact;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtServer
// Procedure sets availability of form items according to the type of server.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabledFromExecutor()
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Crews") Then
		
		Items.GroupContentTeam.Visible 				= True;
		Items.FillCrewMembers.Visible 			= True;
		Items.TabNumber.Visible 						= False;
		
	Else
		
		Items.GroupContentTeam.Visible 				= False;
		Items.FillCrewMembers.Visible 			= False;
		Items.TabNumber.Visible 						= True;
		
		Object.CrewMembers.Clear();
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

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
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		Object.DocumentCurrency = Constants.AccountingCurrency.Get();
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Employees") Then
		TabNumber = Object.Performer.Code;
	Else
		TabNumber = "";
	EndIf;
	
	SetVisibleAndEnabledFromExecutor();
	Items.ClosingDate.AutoMarkIncomplete = Object.Closed;
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("CrewMembersEmployeeCode") <> Undefined Then		
			Items.CrewMembersEmployeeCode.Visible = False;		
		EndIf;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;	
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure // AfterWrite()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;	
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

&AtClient
// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - event handler OnChange input field Performer.
//
Procedure AssigneeOnChange(Item)
	
	SetVisibleAndEnabledFromExecutor();
	Object.CrewMembers.Clear();
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Employees") Then
		TabNumber = GetTabNumber(Object.Performer);
	Else
		TabNumber = "";
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute ItIsClosed.
//
Procedure ClosedOnChange(Item)
	
	If Not ValueIsFilled(Object.ClosingDate) AND Object.Closed Then
		Object.ClosingDate = CurrentDate();	
	EndIf;
	
	If Object.Closed Then
		Items.ClosingDate.AutoMarkIncomplete = True;
	Else	
		Items.ClosingDate.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute CloseDate.
//
Procedure ClosingDateOnChange(Item)
	
	If ValueIsFilled(Object.ClosingDate) Then
		Object.Closed = True;	
	EndIf; 
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange of attribute Period of tabular section Operations.
//
Procedure OperationsPeriodOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	StructureData = New Structure();
	StructureData.Insert("ProcessingDate", 	CurrentRow.Period);
	StructureData.Insert("ProductsAndServices", 	CurrentRow.Operation);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);	
	CurrentRow.Tariff = GetOperationData(StructureData).Price;
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Operation of tabular section Operations.
//
Procedure OperationsOperationOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	StructureData = New Structure();
	StructureData.Insert("ProcessingDate", 	CurrentRow.Period);
	StructureData.Insert("ProductsAndServices", 	CurrentRow.Operation);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	ResultStructure 				= GetOperationData(StructureData);
	CurrentRow.Tariff 			= ResultStructure.Price;
	CurrentRow.MeasurementUnit 	= ResultStructure.MeasurementUnit;
	CurrentRow.TimeNorm 		= ResultStructure.TimeNorm;
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure // InventoryProductsAndServicesOnChange()

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure OperationsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // OperationsProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure OperationCharacteristicChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // OperationCharacteristicChange()

&AtClient
// Procedure - handler of the OnChange event of the Quantity attribute of the Operation tabular section.
//
Procedure OperationsQuantityOnChange(Item)
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the StandartHours attribute of the Operation tabular section.
//
Procedure OperationsTimeNormOnChange(Item)
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the StandardHours attribute of the Operations tabular section.
//
Procedure OperationsStandardHoursOnChange(Item)
	
	CalculateCost();
	
EndProcedure // OperationsStandardHoursOnChange()

&AtClient
// Procedure - OnChange event handler of Tariff attribute of Operations tabular section.
//
Procedure OperationsTariffOnChange(Item)
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure OperationsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Tariff = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Tariff = TabularSectionRow.Tariff * StructureData.Factor / StructureData.CurrentFactor;
		TabularSectionRow.TimeNorm = TabularSectionRow.TimeNorm * StructureData.Factor / StructureData.CurrentFactor;
		CalculateDuration();
		CalculateCost();
	EndIf;
	
	CalculateCost();
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

&AtClient
// Procedure - handler of the OnChange event of the Employee attribute of the CrewMembers tabular section.
//
Procedure CrewMembersEmployeeOnChange(Item)
	
	Items.CrewMembers.CurrentData.LPF = 1;
	
EndProcedure

&AtClient
// Procedure - command handler FillCrewMembers.
//
Procedure FillCrewMembers(Command)
	
	FillCrewMembersAtServer();
	
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
