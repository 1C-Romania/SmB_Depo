
#Region ServiceProceduresAndFunctions

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

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.EndTime - CurrentRow.BeginTime;
	
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	
	CurrentRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	CalculateDurationInHours(CurrentRow);

EndProcedure

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDurationInHours(CurrentRow)
	
	CurrentRow.DurationInHours = Round(Hour(CurrentRow.Duration) + Minute(CurrentRow.Duration) / 60, 2);
	
EndProcedure

&AtServer
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDurationAtServer(CurrentRow)
	
	DurationInSeconds = CurrentRow.EndTime - CurrentRow.BeginTime;
	
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	
	CurrentRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	CurrentRow.DurationInHours = Round(Hour(CurrentRow.Duration) + Minute(CurrentRow.Duration) / 60, 2);
	
EndProcedure

&AtClient
// Procedure calculates amount.
//
// Parameters:
//  No.
//
Procedure CalculateAmount(CurrentRow)
	
	CurrentRow.Amount = CurrentRow.DurationInHours * CurrentRow.Price;
	
EndProcedure

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabledFromOperationKind()
	
	If OperationKind = Enums.OperationKindsWorkOrder.External Then
		
		Items.PriceKind.Visible 				= True;
		Items.GroupCost.Visible 		= True;
		Items.WorksConsumer.Visible 		= True;
		Items.WorksProductsAndServices.Visible 	= True;
		Items.WorksCharacteristic.Visible = True;
		
		Items.WorksRowConsumer.Visible 		= True;
		Items.WorksRowProductsAndServices.Visible 	= True;
		Items.WorksRowCharacteristic.Visible	= True;
		
		Items.WorksPrice.Visible = True;
		Items.WorksAmount.Visible = True;
		
		Items.TotalsAmount.Visible = True;
		
	ElsIf OperationKind = Enums.OperationKindsWorkOrder.Inner Then
		
		Items.PriceKind.Visible 					= False;
		Items.GroupCost.Visible 			= False;
		Items.WorksConsumer.Visible 			= False;
		Items.WorksProductsAndServices.Visible 		= False;
		Items.WorksCharacteristic.Visible 	= False;
		
		Items.WorksRowConsumer.Visible 		= False;
		Items.WorksRowProductsAndServices.Visible 	= False;
		Items.WorksRowCharacteristic.Visible 	= False;
		
		Items.WorksPrice.Visible = False;
		Items.WorksAmount.Visible = False;
		
		Items.TotalsAmount.Visible = False;
		
		For Each TSRow IN Object.Works Do
			TSRow.Price = 0;
			TSRow.Amount = 0;
		EndDo;
		
	EndIf; 
	
	ThisIsFullRights = IsInRole(Metadata.Roles.FullRights);
	
	Items.PriceKind.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddChangeMarketingSubsystem);
	Items.GroupCost.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddChangeSalesSubsystem);
	Items.ConsumerWorkService.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddChangeSalesSubsystem);
	
EndProcedure // SetVisibleAndEnabled()

// Procedure sets the form item visible.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleFromUserSettings()	
	
	If Object.WorkKindPosition = Enums.AttributePositionOnForm.InHeader Then
		Items.WorksWorksKind.Visible = False;
		Items.WorksRowJobKind.Visible = False;
		WorkKindInHeader = True;
		
		Items.WorkKind.Visible = True;
		Items.WorksRowJobKind.Visible = False;
		Items.WorkKindAsList.Visible = True;
		
	Else
		Items.WorksWorksKind.Visible = True;
		Items.WorksRowJobKind.Visible = True;
		WorkKindInHeader = False;
		
		Items.WorkKind.Visible = False;
		Items.WorksRowJobKind.Visible = True;
		Items.WorkKindAsList.Visible = False;
		
	EndIf;	
	
EndProcedure // SetVisibleFromUserSettings()

// Procedure - Set edit by list option.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	
	LineCount = Object.Works.Count();
	
	If Not Items.EditInList.Check
		  AND Object.Works.Count() > 1 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)), 
			NStr("en='All rows except the first will be deleted. Continue?'"),
			QuestionDialogMode.YesNo
		);
        Return;
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
    
    LineCount = AdditionalParameters.LineCount;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Items.EditInList.Check = True;
        Return;
    EndIf;
    
    While LineCount > 1 Do
        Object.Works.Delete(Object.Works[LineCount - 1]);
        LineCount = LineCount - 1;
    EndDo;
    Items.Works.CurrentRow = Object.Works[0].GetID();
    
    SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure SetEditInListFragmentOption()
    
    If Items.EditInList.Check Then
        Items.Pages.CurrentPage = Items.List;
    Else
        Items.Pages.CurrentPage = Items.OneRow;
    EndIf;

EndProcedure // SetEditByListOption()

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary when recalculation
//  DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// 1. Filter by products and services	
	ProductsAndServicesArray = New Array;	
	For Each TSRow IN DocumentTabularSection Do		
		ProductsAndServicesArray.Add(TSRow.ProductsAndServices);
	EndDo;
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;	
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	ProductsAndServicesPricesSliceLast.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency AS ProductsAndServicesPricesCurrency,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(ProductsAndServicesPricesSliceLast.Price, 0) AS Price
	|FROM
	|	InformationRegister.ProductsAndServicesPrices.SliceLast(
	|			&ProcessingDate,
	|			PriceKind = &PriceKind
	|				AND ProductsAndServices IN (&ProductsAndServicesArray)) AS ProductsAndServicesPricesSliceLast
	|WHERE
	|	ProductsAndServicesPricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("ProductsAndServicesArray", ProductsAndServicesArray);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow IN DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
										
				Else	
					
					RoundingOrder = SearchResult[0].RoundingOrder;
					RoundUp = SearchResult[0].RoundUp;
				
				EndIf; 
				
				TabularSectionRow.Price = SmallBusinessServer.RoundPrice(Price, RoundingOrder, RoundUp); 
				
			EndIf;
			
		Else
			
			TabularSectionRow.Price = 0;
		
		EndIf;
		
	EndDo;
	
EndProcedure // GetTabularSectionPricesByPriceKind()

&AtServerNoContext
// Gets job price.
//
Function GetPrice(StructureData)
	
	StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	StructureData.Insert("AmountIncludesVAT", StructureData.PriceKind.PriceIncludesVAT);
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	StructureData.Insert("Factor", 1);
	
	StructureData.Insert("Price", SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

#EndRegion

#Region FormCommandsHandlers

// Procedure - EditByList command handler.
//
&AtClient
Procedure EditInList(Command)
	
	SetEditInListOption();
	
EndProcedure // EditByList()

// Procedure - command handler DocumentSetting.
//
&AtClient
Procedure DocumentSetting(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WorkKindPositionInWorkTask", 	Object.WorkKindPosition);
	ParametersStructure.Insert("WereMadeChanges", 				False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
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
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	If Object.Works.Count() = 0 Then
		NewRow = Object.Works.Add();
		If Not ValueIsFilled(Object.Ref)
		   AND Not ValueIsFilled(Parameters.CopyingValue) Then
			If Parameters.FillingValues.Property("Customer")
			   AND ValueIsFilled(Parameters.FillingValues.Customer) Then
				NewRow.Customer = Parameters.FillingValues.Customer;
			EndIf;
			If Parameters.Property("BeginTime") Then 
				NewRow.Day = BegOfDay(Parameters.BeginTime);
				NewRow.BeginTime = Parameters.BeginTime;
			EndIf;
			If Parameters.Property("EndTime") Then 
				NewRow.EndTime = Parameters.EndTime;
			EndIf;
			CalculateDurationAtServer(NewRow);
			
		EndIf;
		Items.Works.CurrentRow = NewRow.GetID();
	Else
		Items.Works.CurrentRow = Object.Works[0].GetID();
	EndIf;
	
	OperationKind = Object.OperationKind;
	
	SetVisibleAndEnabledFromOperationKind();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("EmployeeCode") <> Undefined Then
			Items.EmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	If Parameters.Property("Employee") Then // for filling from manager contacts.
		Object.Employee = Parameters.Employee;
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ChangesProhibitionDates
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ChangesProhibitionDates
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)
	
	LineCount = Object.Works.Count();
	Items.EditInList.Check = LineCount > 1;
	
	If Items.EditInList.Check Then
		Items.Pages.CurrentPage = Items.List;
	Else
		Items.Pages.CurrentPage = Items.OneRow;
	EndIf;
	
EndProcedure

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
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties 
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

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
// IN procedure the document number is cleared, and also 
// the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - event handler OnChange of the OperationKind input field.
//
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If TypeOfOperationsBeforeChange <> OperationKind Then
		SetVisibleAndEnabledFromOperationKind();
	EndIf;
	
EndProcedure // OperationKindOnChange()

&AtClient
// Procedure - event handler OnChange input field WorkKind.
//
Procedure WorkKindOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("ProcessingDate", 	Object.Date);
	StructureData.Insert("ProductsAndServices", 	Object.WorkKind);
	StructureData.Insert("PriceKind", 			Object.PriceKind);	
	
	Price = GetPrice(StructureData).Price;
	
	For Each TSRow IN Object.Works Do		
		TSRow.Price = Price;
		CalculateAmount(TSRow);		
	EndDo;
	
EndProcedure // WorkKindOnChange()

&AtClient
// Procedure - event handler OnChange of the PriceKind input field.
//
Procedure PricesKindOnChange(Item)
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			Counterparty);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	
	If WorkKindInHeader Then
	
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices",		Object.WorkKind);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
	
	Else
	
		For Each TSRow IN Object.Works Do
			
			TSRow.Price = 0;
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("ProductsAndServices",		TSRow.WorkKind);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;		
	
	EndIf;
		
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	If WorkKindInHeader Then
		
		Price = DocumentTabularSection[0].Price;
		
		For Each TSRow IN Object.Works Do		
			TSRow.Price = Price;
			CalculateAmount(TSRow);		
		EndDo;
	
	Else
	
		For Each TSRow IN DocumentTabularSection Do

			SearchStructure = New Structure;
			SearchStructure.Insert("WorkKind", TSRow.ProductsAndServices);
			
			SearchResult = Object.Works.FindRows(SearchStructure);
			
			For Each ResultRow IN SearchResult Do				
				ResultRow.Price = TSRow.Price;
				CalculateAmount(ResultRow);				
			EndDo;
			
		EndDo;		
	
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit tabular section Works.
//
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Not Copy Then
		
		If WorkKindInHeader Then
	
			CurrentRow = Items.Works.CurrentData;
			
			StructureData = New Structure();
			StructureData.Insert("ProcessingDate", 	Object.Date);
			StructureData.Insert("ProductsAndServices", 	Object.WorkKind);
			StructureData.Insert("PriceKind", 			Object.PriceKind);	
			
			CurrentRow.Price = GetPrice(StructureData).Price;
			
			CalculateAmount(CurrentRow);
		
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field WorkKind.
//
Procedure WorksWorkKindOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProcessingDate", 	CurrentRow.Day);
	StructureData.Insert("ProductsAndServices", 	CurrentRow.WorkKind);
	StructureData.Insert("PriceKind", 			Object.PriceKind);	
	
	CurrentRow.Price = GetPrice(StructureData).Price;
	
	CalculateAmount(CurrentRow);
	
EndProcedure // WorkKindOnChange()

&AtClient
// Procedure - handler of event OnChange of input field StartTime.
//
Procedure WorksBeginTimeOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	If CurrentRow.BeginTime > CurrentRow.EndTime Then
		CurrentRow.EndTime = CurrentRow.BeginTime;
	EndIf;
	
	CalculateDuration(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.BeginTime)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CurrentDate();
		
	EndIf;
	
EndProcedure // WorkStartTimeOnChange()

&AtClient
// Procedure - handler of event OnChange of input field EndTime.
//
Procedure WorksEndTimeOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	If CurrentRow.BeginTime > CurrentRow.EndTime Then
		CurrentRow.BeginTime = CurrentRow.EndTime;
	EndIf; 
	
	CalculateDuration(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.EndTime)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CurrentDate();
		
	EndIf;
	
EndProcedure // WorksEndTimeOnChange()

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure WorksPriceOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	CalculateAmount(CurrentRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure WorksAmountOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	CurrentRow.Price = ?(CurrentRow.DurationInHours = 0, 0, CurrentRow.Amount / CurrentRow.DurationInHours);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Duration.
//
Procedure WorksDurationOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60 + Second(CurrentRow.Duration);	
	CurrentRow.EndTime = CurrentRow.BeginTime + DurationInSeconds;
	
	If '00010101235959' - CurrentRow.BeginTime < DurationInSeconds Then	
		CurrentRow.EndTime = '00010101235959';
		CalculateDuration(CurrentRow);		
	EndIf;
	
	CalculateDurationInHours(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.Duration)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CurrentDate();
		
	EndIf;
	
EndProcedure // WorkDurationOnChange()

&AtClient
// Procedure - event handler OnChange of the Day attribute.
//
Procedure WorksDayOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	If ValueIsFilled(CurrentRow.Day)
		AND CurrentRow.BeginTime = BegOfDay(CurrentRow.BeginTime)
		AND CurrentRow.BeginTime = CurrentRow.EndTime Then
		
		CurrentRow.EndTime = EndOfDay(CurrentRow.EndTime) - 59;
		
	ElsIf Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.BeginTime = '00010101';
		CurrentRow.EndTime = '00010101';
		CurrentRow.Duration = '00010101';
		CurrentRow.DurationInHours = 0;
		
	EndIf;
	
EndProcedure // WorkDayOnChange()

&AtClient
// Procedure - event handler ChoiceProcessing of attribute Customer.
//
Procedure WorksConsumerChoiceProcessingChoice(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Type("CatalogRef.CounterpartyContracts") Then
	
		StandardProcessing = False;
		
		SelectedContract = Undefined;

		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceFormWithCounterparty",,,,,, New NotifyDescription("WorkCustomerSelectionDataProcessorEnd", ThisObject));
	
	EndIf;
	
EndProcedure

&AtClient
Procedure WorkCustomerSelectionDataProcessorEnd(Result, AdditionalParameters) Export
    
    SelectedContract = Result;
    
    If TypeOf(SelectedContract) = Type("CatalogRef.CounterpartyContracts")Then
        CurrentRow = Items.Works.CurrentData;	
        CurrentRow.Customer = SelectedContract;
    EndIf;

EndProcedure

&AtClient
// Procedure - event handler StartChoice of the Comment attribute of the Works tabular section.
//
Procedure WorksCommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Works.CurrentData;
	FormParameters = New Structure("Text, Title", CurrentData.Comment, "Comment edit");  
	ReturnComment = Undefined;
  
	OpenForm("CommonForm.TextEdit", FormParameters,,,,, New NotifyDescription("WorkCommentSelectionStartEnd", ThisObject, New Structure("CurrentData", CurrentData))); 
	
EndProcedure

&AtClient
Procedure WorkCommentSelectionStartEnd(Result, AdditionalParameters) Export
    
    CurrentData = AdditionalParameters.CurrentData;
    
    
    ReturnComment = Result;
    
    If TypeOf(ReturnComment) = Type("String") Then
        
        If CurrentData.Comment <> ReturnComment Then
            Modified = True;
        EndIf;
        
        CurrentData.Comment = ReturnComment;
        
    EndIf;

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("TaskChanged", Object.Employee);
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsResultsHandlers

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructureDocumentSetting = Result;
    
    // 3. Apply changes made in "Document setting" form.
    If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
        
        Object.WorkKindPosition = StructureDocumentSetting.WorkKindPositionInWorkTask;
        SetVisibleFromUserSettings();
        
    EndIf;

EndProcedure

#EndRegion

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
&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EditContentOfProperties()
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
EndProcedure
// End StandardSubsystems.Properties

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
