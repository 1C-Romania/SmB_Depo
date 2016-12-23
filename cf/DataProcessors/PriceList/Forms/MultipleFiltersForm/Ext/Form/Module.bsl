
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
Procedure RadioButtonFilterMode(TabularSectionName)
	
	If Items[TabularSectionName + "List"].Check Then
		
		Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
		
	Else
		
		If Object[TabularSectionName].Count() > 0 Then
		
			QuestionText = NStr("en='Multiple filter will be cleared. Continue?';ru='Множественный отбор будет очищен. Продолжить?'");
			ShowQueryBox(New NotifyDescription("RadioButtonFilterModeEnd", ThisObject, New Structure("TabularSectionName", TabularSectionName)), QuestionText, QuestionDialogMode.YesNo);
            Return;
			
		EndIf;
		
	EndIf;
	
	RadioButtonFilterModeFragment(TabularSectionName);
EndProcedure

&AtClient
Procedure RadioButtonFilterModeEnd(Result, AdditionalParameters) Export
    
    TabularSectionName = AdditionalParameters.TabularSectionName;
    
    
    If Result = DialogReturnCode.Yes Then
        
        Object[TabularSectionName].Clear();
        
    Else
        
        Items[TabularSectionName + "List"].Check = Not Items[TabularSectionName + "List"].Check;
        
    EndIf;
    
    
    RadioButtonFilterModeFragment(TabularSectionName);

EndProcedure

&AtClient
Procedure RadioButtonFilterModeFragment(Val TabularSectionName)
    
    ChangeFilterPage(TabularSectionName, Items[TabularSectionName + "List"].Check);

EndProcedure

&AtClient
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		
		DecorationTitle = "Multiple filter is not filled";
		
	ElsIf Object[TabularSectionName].Count() > 1 Then
		
		DecorationTitle = "Selected items: " + String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref) + "...";
		
	Else
		
		DecorationTitle = "Selected item: " + String(Object[TabularSectionName][0].Ref);
		
	EndIf;
	
	Return DecorationTitle;
	
EndFunction

&AtClient
Procedure ChangeFilterPage(TabularSectionName, List)
	
	GroupPages = Items["FilterPages" + TabularSectionName];
	
	SetAsCurrentPage = Undefined;
	
	For Each PageOfGroup in GroupPages.ChildItems Do
		
		If List Then
			
			If Find(PageOfGroup.Name, "MultipleFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
			
			EndIf;
			
		Else
			
			If Find(PageOfGroup.Name, "QuickFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
	
	GroupPages.CurrentPage = SetAsCurrentPage;
	
EndProcedure

&AtClient
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow IN Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction

&AtClient
Procedure FillTabularSectionFromArrayItemsAtClient(TabularSectionName, ItemArray, ClearTable)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement IN ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTabularSectionFromArrayItemsAtServer(TabularSectionName, ItemArray, ClearTable = True)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement IN ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	Items[TabularSectionName + "List"].Check = (ItemCount > 0);
	
	ChangeFilterPage(TabularSectionName, Items[TabularSectionName + "List"].Check);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ToDate 							= Parameters.ToDate;
	Actuality					= Parameters.Actuality;
	EnableAutoCreation		= Parameters.EnableAutoCreation;
	OutputCode						= Constants.PriceListShowCode.Get();
	OutputFullDescr		= Constants.PriceListShowFullDescr.Get();
	ItemHierarchy			= Constants.PriceListUseProductsAndServicesHierarchy.Get();
	FormateByAvailabilityInWarehouses	= Constants.FormPriceListByAvailabilityInWarehouses.Get();
	
	If TypeOf(Parameters.PriceKind) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("PriceKinds", Parameters.PriceKind, True);
		
	Else
		
		PriceKind = Parameters.PriceKind;
		
	EndIf;
	
	If TypeOf(Parameters.PriceGroup) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("PriceGroups", Parameters.PriceGroup, True);
		
	Else
		
		PriceGroup = Parameters.PriceGroup;
		
	EndIf;
	
	If TypeOf(Parameters.ProductsAndServices) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("ProductsAndServices", Parameters.ProductsAndServices, True);
		
	Else
		
		ProductsAndServices = Parameters.ProductsAndServices;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.PriceKindsList.Check = (Object.PriceKinds.Count() > 0);
	ChangeFilterPage("PriceKinds", Items.PriceKindsList.Check);
	
	Items.PriceGroupsList.Check = (Object.PriceGroups.Count() > 0);
	ChangeFilterPage("PriceGroups", Items.PriceGroupsList.Check);
	
	Items.ProductsAndServicesList.Check = (Object.ProductsAndServices.Count() > 0);
	ChangeFilterPage("ProductsAndServices", Items.ProductsAndServicesList.Check);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = (Find(ChoiceSource.FormName, "DataProcessor.PriceList") > 0);
		
		If ChoiceSource.FormName = "Catalog.PriceKinds.Form.ChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.PriceList.Form.PricesKindsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceKinds", ValueSelected, ClearTable);
			AnalyzeChoice("PriceKinds");
			
		ElsIf ChoiceSource.FormName = "Catalog.PriceGroups.Form.ChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.PriceList.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "Catalog.ProductsAndServices.Form.ChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.PriceList.Form.ProductsAndServicesEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("ProductsAndServices", ValueSelected, ClearTable);
			AnalyzeChoice("ProductsAndServices");
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

&AtClient
Procedure CounterpartiesList(Command)
	
	Items.CounterpartiesList.Check = Not Items.CounterpartiesList.Check;
	
	If ValueIsFilled(Counterparty) 
		AND Items.CounterpartiesList.Check Then
		
		NewRow			= Object.Counterparties.Add();
		NewRow.Ref	= Counterparty;
		
		Counterparty 			= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("Counterparties");
	
EndProcedure

&AtClient
Procedure PricesKindList(Command)
	
	Items.PriceKindsList.Check = Not Items.PriceKindsList.Check;
	
	If ValueIsFilled(PriceKind) 
		AND Items.PriceKindsList.Check Then
		
		NewRow 		= Object.PriceKinds.Add();
		NewRow.Ref	= PriceKind;
		
		PriceKind				= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("PriceKinds");
	
EndProcedure

&AtClient
Procedure PriceGroupsList(Command)
	
	Items.PriceGroupsList.Check = Not Items.PriceGroupsList.Check;
	
	If ValueIsFilled(PriceGroup) 
		AND Items.PriceGroupsList.Check Then
		
		NewRow 		= Object.PriceGroups.Add();
		NewRow.Ref	= PriceGroup;
		
		PriceGroup		= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("PriceGroups");
	
EndProcedure

&AtClient
Procedure ProductsAndServicesList(Command)
	
	Items.ProductsAndServicesList.Check = Not Items.ProductsAndServicesList.Check;
	
	If ValueIsFilled(ProductsAndServices) 
		AND Items.ProductsAndServicesList.Check Then
		
		NewRow 		= Object.ProductsAndServices.Add();
		NewRow.Ref	= ProductsAndServices;
		
		ProductsAndServices		= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("ProductsAndServices");
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterPriceKindsClick(Item)
	
	If Object.PriceKinds.Count() > 0 Then
		
		OpenForm("DataProcessor.PriceList.Form.PricesKindsEditForm", New Structure("ArrayPriceKinds", FillArrayByTabularSectionAtClient("PriceKinds")), ThisForm);
		
	Else
		
		OpenForm("Catalog.PriceKinds.Form.ChoiceForm", New Structure("Multiselect", True), ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterPriceGroupsClick(Item)
	
	If Object.PriceGroups.Count() > 0 Then
		
		OpenForm("DataProcessor.PriceList.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
		
	Else
		
		OpenForm("Catalog.PriceGroups.Form.ChoiceForm", New Structure("Multiselect", True), ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterPriceProductsAndServicesClick(Item)
	
	If Object.ProductsAndServices.Count() > 0 Then
		
		OpenForm("DataProcessor.PriceList.Form.ProductsAndServicesEditForm", New Structure("ProductsAndServicesArray", FillArrayByTabularSectionAtClient("ProductsAndServices")), ThisForm);
		
	Else
		
		OpenForm("Catalog.ProductsAndServices.Form.ChoiceForm", New Structure("Multiselect, GroupsAndItemsChoice", True, FoldersAndItemsUse.FoldersAndItems), ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate", 						ToDate);
	FormParameters.Insert("Actuality",					Actuality);
	FormParameters.Insert("EnableAutoCreation",	EnableAutoCreation);
	FormParameters.Insert("OutputCode",					OutputCode);
	FormParameters.Insert("OutputFullDescr",	OutputFullDescr);
	FormParameters.Insert("ItemHierarchy", 		ItemHierarchy);
	FormParameters.Insert("FormateByAvailabilityInWarehouses", FormateByAvailabilityInWarehouses);
	
	ParameterValue = ?(Items.PriceKindsList.Check, FillArrayByTabularSectionAtClient("PriceKinds"), PriceKind);
	FormParameters.Insert("PriceKind", ParameterValue);
	
	ParameterValue = ?(Items.PriceGroupsList.Check, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Items.ProductsAndServicesList.Check, FillArrayByTabularSectionAtClient("ProductsAndServices"), ProductsAndServices);
	FormParameters.Insert("ProductsAndServices", ParameterValue);
	
	Notify("MultipleFilters", FormParameters);
	Close();
	
EndProcedure

















