////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		SmallBusinessServer.GetCompany(Company)		
	);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume);
	
	Return StructureData;
	
EndFunction // ReceiveDataFixedAsset()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtServer
// Receives the flag of Order warehouse.
//
Procedure SetCellVisible(CellName, Warehouse)
	
	Items[CellName].Visible = Not Warehouse.OrderWarehouse;
	
EndProcedure // SetCellVisible()	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler "OnCreateAtServer".
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Items.Cell.Visible = Not Object.StructuralUnit.OrderWarehouse;
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
	MainDivision = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
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
	
	Notify("FixedAssetsStatesUpdate");
	
EndProcedure // AfterWrite()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

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
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ProductsAndServicesOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",Object.ProductsAndServices);
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	Object.MeasurementUnit = StructureData.MeasurementUnit;
	
EndProcedure // ProductsAndServicesOnChange()

&AtClient
// Procedure - event handler OnChange of the StructuralUnit input field.
//
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible("Cell", Object.StructuralUnit);
	
EndProcedure // StructuralUnitOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDivision;
		
	EndIf;
	
EndProcedure // FixedAssetsOnStartEdit()

&AtClient
// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Volume of Production Work for calculating depreciation ""can not be filled with for the specified depreciation accrual method!'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange()

&AtClient
// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'The useful life of the asset can not be filled for the specified method of calculating depreciation!'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsUsagePeriodForDepreciationCalculationOnChange()

&AtClient
// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsFixedAssetOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
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
