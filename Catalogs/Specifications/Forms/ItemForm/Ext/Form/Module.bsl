
&AtClient
Var CurrentTypeOfContentRow;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("TimeNorm", StructureData.ProductsAndServices.TimeNorm);
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

&AtServerNoContext
// Returns the result of checking the match of content row type and products and services type.
//
Function CorrespondsRowTypeProductsAndServicesType(StructureData)
	
	If (StructureData.ContentRowType = PredefinedValue("Enum.SpecificationContentRowTypes.Expense")
		AND StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"))
		OR (StructureData.ContentRowType <> PredefinedValue("Enum.SpecificationContentRowTypes.Expense")
		AND StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service")) Then
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Mechanism handler "ObjectVersioning".
	ObjectVersioning.OnCreateAtServer(ThisForm);
	
	If Not Constants.FunctionalOptionUseTechOperations.Get() Then
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Specifications.TabularSections.Content, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange input field ContentRowType.
//
Procedure ContentTypeOfContentRowOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.ContentRowType)
		AND ValueIsFilled(TabularSectionRow.ProductsAndServices) Then
		
		StructureData = New Structure();
		StructureData.Insert("ContentRowType", TabularSectionRow.ContentRowType);
		StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
		
		If Not CorrespondsRowTypeProductsAndServicesType(StructureData) Then
			
			TabularSectionRow.ProductsAndServices = Undefined;
			TabularSectionRow.Characteristic = Undefined;
			TabularSectionRow.MeasurementUnit = Undefined;
			TabularSectionRow.Specification = Undefined;
			TabularSectionRow.Quantity = 1;
			TabularSectionRow.ProductsQuantity = 1;
			TabularSectionRow.CostPercentage = 1;
			
		EndIf;
		
	EndIf;
	
EndProcedure // ContentTypeOfContentRowOnChange()

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ContentProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Characteristic = Undefined;
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.ProductsQuantity = 1;
	TabularSectionRow.CostPercentage = 1;
	
EndProcedure // ContentProductsAndServicesOnChange()

// Procedure - event handler StartChoice field ProductsAndServices.
//
&AtClient
Procedure ContentProductsAndServicesStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Set selection parameters of products and services depending on content row type
	FilterArray = New Array;
	
	If Items.Content.CurrentData.ContentRowType = PredefinedValue("Enum.SpecificationContentRowTypes.Expense") Then
		FilterArray.Add(PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
	Else
		FilterArray.Add(PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	EndIf;
	
	ChoiceParameter = New ChoiceParameter("Filter.ProductsAndServicesType", New FixedArray(FilterArray));
	SelectionParametersArray = New Array();
	SelectionParametersArray.Add(ChoiceParameter);
	Item.ChoiceParameters = New FixedArray(SelectionParametersArray);
	
EndProcedure // ContentProductsAndServicesStartChoice()

&AtClient
Procedure ContentProductsAndServicesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	// Prohibit loop references
	If ValueSelected = Object.Owner Then
		CommonUseClientServer.MessageToUser(NStr("en='Products can not be the part of the specification.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure ContentCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // ContentCharacteristicOnChange()

&AtClient
// Procedure - event handler OnChange input field Operation.
//
Procedure OperationsOperationOnChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.Operation);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.TimeNorm = StructureData.TimeNorm;
	TabularSectionRow.ProductsQuantity = 1;
	
EndProcedure // InventoryProductsAndServicesOnChange()

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

// StandardSubsystems.DataLoadFromFile
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
			
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			Object.Content.Clear();
			
			DataMatchingTable = ImportResult.DataMatchingTable;
			For Each TableRow IN DataMatchingTable Do
				
				If TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()] Then
					
					FillPropertyValues(Object.Content.Add(), TableRow);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure
// End StandardSubsystems. DataLoadFromFile

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
