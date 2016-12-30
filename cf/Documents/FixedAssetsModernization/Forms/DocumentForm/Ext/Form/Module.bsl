////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillTableFixedAssets()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DepreciationParametersSliceLast.FixedAsset AS FixedAsset,
	|	DepreciationParametersSliceLast.StructuralUnit AS Department,
	|	DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DepreciationParametersSliceLast.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DepreciationParametersSliceLast.GLExpenseAccount AS GLExpenseAccount,
	|	DepreciationParametersSliceLast.BusinessActivity AS BusinessActivity
	|FROM
	|	InformationRegister.FixedAssetsParameters.SliceLast(&DocumentDate, Company = &Company) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("DocumentDate", Object.Date);
	Query.SetParameter("Company", SubsidiaryCompany);
	
	QueryResultTable = Query.Execute().Unload();
	TableFixedAssets.Load(QueryResultTable);
	
EndProcedure // FillTableFixedAssets()

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
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume);
	
	Return StructureData;
	
EndFunction // ReceiveDataFixedAsset()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
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
	
	FillTableFixedAssets();
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
	
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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PROPERTY TABULAR SECTION ATTRIBUTES

&AtClient
// Procedure - event handler OnStartEdit of the FixedAssets list row.
//
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;	
	
EndProcedure // FixedAssetsOnStartEdit()

&AtClient
// Procedure - event handler OnChange of the WorksProductsVolumeForDepreciationCalculation input field 
// in the row of the FixedAssets
// tabular section.
//
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en='""Volume of Production Work for calculating depreciation ""can not be filled with for the specified depreciation accrual method!';ru='""Объем продукции (работ) для исчисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange()

&AtClient
// Procedure - event handler OnChange of the UsagePeriodForDepreciationCalculation input field 
// in the row of the FixedAssets
// tabular section.
//
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en='The useful life of the asset can not be filled for the specified method of calculating depreciation!';ru='""Срок использования для вычисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsUsagePeriodForDepreciationCalculationOnChange()

&AtClient
// Procedure - event handler OnChange of the
// FixedAsset input field in the row
// of the FixedAssets tabular section.
//
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	FixedAssetsArray = TableFixedAssets.FindRows(New Structure("FixedAsset", Items.FixedAssets.CurrentData.FixedAsset));
	
	If FixedAssetsArray.Count() <> 0 Then
		Items.FixedAssets.CurrentData.UsagePeriodForDepreciationCalculation = FixedAssetsArray[0].UsagePeriodForDepreciationCalculation;
		Items.FixedAssets.CurrentData.AmountOfProductsServicesForDepreciationCalculation = FixedAssetsArray[0].AmountOfProductsServicesForDepreciationCalculation;
		Items.FixedAssets.CurrentData.CostForDepreciationCalculation = FixedAssetsArray[0].CostForDepreciationCalculation;
		Items.FixedAssets.CurrentData.CostForDepreciationCalculationBeforeChanging = FixedAssetsArray[0].CostForDepreciationCalculation;
		Items.FixedAssets.CurrentData.GLExpenseAccount = FixedAssetsArray[0].GLExpenseAccount;
		Items.FixedAssets.CurrentData.RevaluationAccount = PredefinedValue("ChartOfAccounts.Managerial.OtherIncome");
		Items.FixedAssets.CurrentData.BusinessActivity = FixedAssetsArray[0].BusinessActivity;
		Items.FixedAssets.CurrentData.StructuralUnit = FixedAssetsArray[0].Department;
	Else
		Items.FixedAssets.CurrentData.UsagePeriodForDepreciationCalculation = 0;
		Items.FixedAssets.CurrentData.AmountOfProductsServicesForDepreciationCalculation = 0;
		Items.FixedAssets.CurrentData.CostForDepreciationCalculation = 0;
		Items.FixedAssets.CurrentData.CostForDepreciationCalculationBeforeChanging = 0;
	EndIf;
	
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













