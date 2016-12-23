#Region ServiceProceduresAndFunctions

#Region ListSorting

// The procedure checks the configured sorting by the
// attribute "AdditionalSortingAttribute" and suggests to set this sorting.
//
&AtClient
Procedure ValidateListFilter()
	
	SortingSetupParameters = New Structure;
	SortingSetupParameters.Insert("ListAttribute", List);
	SortingSetupParameters.Insert("ListItem", Items.List);
	
	If Not SortInListIsSetCorrectly(List) Then
		QuestionText = NStr("en='It is recommended
		|to sort the list by the field ""Order"". Configure the necessary sorting?';ru='Сортировку
		|списка рекомендуется установить по полю ""Порядок"". Настроить необходимую сортировку?'");
		NotifyDescription = New NotifyDescription("CheckListBeforeOperationResponseForSortingReceived", ThisObject, SortingSetupParameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en='Configure';ru='Настроить'"));
		Buttons.Add(DialogReturnCode.No, NStr("en='Do not configure';ru='Не настраивать'"));
		ShowQueryBox(NOTifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
EndProcedure

// The function checks that the list is sorted by the attribute AdditionalOrderingAttribute.
//
&AtClient
Function SortInListIsSetCorrectly(List)
	
	UserOrderSettings = Undefined;
	For Each Item IN List.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	If UserOrderSettings = Undefined Then
		Return True;
	EndIf;
	
	OrderItems = UserOrderSettings.Items;
	
	// Find the first used order item
	Item = Undefined;
	For Each OrderingItem IN OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No sorting is set
		Return False;
	EndIf;
	
	If TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			AttributeField = New DataCompositionField("AdditionalOrderingAttribute");
			If Item.Field = AttributeField Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// The procedure processes user response to the question about the sorting by the attribute AdditionalOrderingAttribute.
//
&AtClient
Procedure CheckListBeforeOperationResponseForSortingReceived(ResponseResult, AdditionalParameters) Export
	
	If ResponseResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetListSortingByFieldOrder();
	
EndProcedure

// The procedure sets the order by the field AdditionalOrderingAttribute.
//
&AtClient
Procedure SetListSortingByFieldOrder()
	
	ListAttribute = List;
	
	UserOrderSettings = Undefined;
	For Each Item IN ListAttribute.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	CommonUseClientServer.Validate(UserOrderSettings <> Undefined, NStr("en='Custom settings for order not found.';ru='Пользовательская настройка порядка не найдена.'"));
	
	UserOrderSettings.Items.Clear();
	Item = UserOrderSettings.Items.Add(Type("DataCompositionOrderItem"));
	Item.Use = True;
	Item.Field = New DataCompositionField("AdditionalOrderingAttribute");
	Item.OrderType = DataCompositionSortDirection.Asc;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;
	
	SharedUsageVariantOfDiscounts = Constants.DiscountsMarkupsSharedUsageOptions.Get();
	If SharedUsageVariantOfDiscounts.IsEmpty() Then
		SharedUsageVariantOfDiscounts = Enums.DiscountsMarkupsSharedUsageOptions.Addition;
		Constants.DiscountsMarkupsSharedUsageOptions.Set(SharedUsageVariantOfDiscounts);
	EndIf;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsMarkupsSharedUsageOptions.Exclusion")
		OR SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsMarkupsSharedUsageOptions.Multiplication") Then
		SetListSortingByFieldOrder();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - CreateJointApplicationGroup command handler of the form.
//
&AtClient
Procedure CreateFolderSharedUse(Presentation)
	
	GroupFormParameters = New Structure("IsFolder", True);
	OpenForm("Catalog.AutomaticDiscounts.FolderForm", GroupFormParameters,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item DiscountsSharedUsageOption.
//
&AtClient
Procedure SharedUsageVariantOfDiscountsOnChange(Item)
	
	DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts);
	If SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsMarkupsSharedUsageOptions.Exclusion")
		OR SharedUsageVariantOfDiscounts = PredefinedValue("Enum.DiscountsMarkupsSharedUsageOptions.Multiplication") Then
		ValidateListFilter();
	EndIf;
	Items.List.Refresh();
	
EndProcedure

// Procedure - event handler OnChange item DiscountsJointApplicationOption (server part).
//
&AtServerNoContext
Procedure DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts)
	
	Constants.DiscountsMarkupsSharedUsageOptions.Set(SharedUsageVariantOfDiscounts);
	
EndProcedure

#EndRegion














