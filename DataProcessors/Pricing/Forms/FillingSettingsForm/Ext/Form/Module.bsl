
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS



////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtClient
// The procedure changes the
// availability of the form items depending on the selected filling option
//
// Implementation of the form items
// accessibility using pages is connected to the need to reduce the number of server calls.
//
// FormAttributeName - name of the enabled switcher.
//
Procedure ChangeFormItemsAvailability(FormAttributeName)
	
	MapOfPriceKindPages = New Map;
	MapOfPriceKindPages.Insert(True, 	Items.PriceKindAvailable);
	MapOfPriceKindPages.Insert(False, 		Items.PriceKindIsNotAvailable);
	
	ConformityToPagesBlankPricesBasedOnPrices  = New Map;
	ConformityToPagesBlankPricesBasedOnPrices.Insert(True,	Items.UnfilledPricesByPriceKindAvailable);
	ConformityToPagesBlankPricesBasedOnPrices.Insert(False, 	Items.BlankPricesBasedOnPriceNotAvailable);
	
	MapOfProductsAndServicesGroupsPages = New Map;
	MapOfProductsAndServicesGroupsPages.Insert(True, 	Items.ProductsAndServicesGroupIsAvailable);
	MapOfProductsAndServicesGroupsPages.Insert(False, 	Items.ProductsAndServicesGroupIsNotAvailable);
	
	MapOfSupplierInvoicePages = New Map;
	MapOfSupplierInvoicePages.Insert(True, 	Items.GroupSupplierInvoiceAvailable);
	MapOfSupplierInvoicePages.Insert(False, 	Items.GroupSupplierInvoiceNotAvailable);
	
	MapOfPriceGroupsPages = New Map;
	MapOfPriceGroupsPages.Insert(True, 	Items.GroupPriceGroupAvailable);
	MapOfPriceGroupsPages.Insert(False, 	Items.GroupPriceGroupIsNotAvailable);
	
	MapOfAttributesAndRadioButtons = New Map;
	MapOfAttributesAndRadioButtons.Insert("AddOnPrice",				MapOfPriceKindPages);
	MapOfAttributesAndRadioButtons.Insert("AddBlankPricesByPriceKind", ConformityToPagesBlankPricesBasedOnPrices);
	MapOfAttributesAndRadioButtons.Insert("AddByProductsAndServicesGroup",	MapOfProductsAndServicesGroupsPages);
	MapOfAttributesAndRadioButtons.Insert("AddToInvoiceReceipt", 	MapOfSupplierInvoicePages);
	MapOfAttributesAndRadioButtons.Insert("AddByPriceGroup", 		MapOfPriceGroupsPages);
	
	For Each MapItem IN MapOfAttributesAndRadioButtons Do
		
		SuccessfullyIdentified = (MapItem.Key = FormAttributeName);
		
		If Not SuccessfullyIdentified Then
			
			// Enable the switcher
			ThisForm[MapItem.Key] = ""; 
			
		EndIf;
		
		NewCurrentPage = MapItem.Value.Get(SuccessfullyIdentified);
		NewCurrentPage.Parent.CurrentPage = NewCurrentPage;
		
	EndDo;
	
EndProcedure // ChangeFormItemsAvailability()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler of the OnCreateAtServer form
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisForm.CloseOnChoice = False;
	AddOnPrice 			= "AddOnPrice";
	
EndProcedure //OnCreateAtServer()

&AtClient
// Procedure - form event handler OnOpen
//
Procedure OnOpen(Cancel)
	
	ChangeFormItemsAvailability("AddOnPrice")
	
EndProcedure //OnOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// The procedure initiates adding of new products and services items
//
Procedure AddProductsAndServices(Command)
	
	ParametersStructure = New Structure;
	
	// Empty values of switchers collapse automatically
	MapOfAttributesAndRadioButtons = New Map;
	MapOfAttributesAndRadioButtons.Insert(AddOnPrice,				PriceKind);
	MapOfAttributesAndRadioButtons.Insert(AddBlankPricesByPriceKind, PriceKindOfPriceNezapolnena);
	MapOfAttributesAndRadioButtons.Insert(AddByProductsAndServicesGroup,	ProductsAndServicesGroup);
	MapOfAttributesAndRadioButtons.Insert(AddToInvoiceReceipt,	SupplierInvoice);
	MapOfAttributesAndRadioButtons.Insert(AddByPriceGroup, 		PriceGroup);
	
	For Each MapItem IN MapOfAttributesAndRadioButtons Do
		
		If ValueIsFilled(MapItem.Key) Then
			
			ParametersStructure.Insert("FillVariant",			MapItem.Key);
			ParametersStructure.Insert("ValueSelected",			MapItem.Value);
			
			If MapItem.Key = "AddOnPrice" Then
				
				ParametersStructure.Insert("ToDate", ?(ValueIsFilled(ToDate), ToDate, CurrentDate()));
				
			ElsIf MapItem.Key = "AddBlankPricesByPriceKind" Then
				
				ParametersStructure.Insert("ToDate", ?(ValueIsFilled(OnDateBlankPrices), OnDateBlankPrices, CurrentDate()));
				
			EndIf;
			
			ParametersStructure.Insert("UseCharacteristics",	UseCharacteristics);
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not ValueIsFilled(ParametersStructure.ValueSelected) Then
		
		MessageText = NStr("en = 'Filter value for filling has not been selected'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	NotifyChoice(ParametersStructure);
	
EndProcedure //AddProductsAndServices()

&AtClient
// Procedure - event handler OnChange attribute FillByPriceKindOnChange
//
Procedure AddByPriceKindOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure // FillByPriceKindOnChange()

&AtClient
// Procedure - event handler OnChange attribute AddBlankPricesByPriceKind
//
Procedure AddBlankPricesByPriceKindOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure //AddBlankPricesByPriceKindOnChange()

&AtClient
// Procedure - event handler OnChange attribute FillByProductsAndServicesGroup
//
Procedure AddByProductsAndServicesGroupOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure // FillByProductsAndServicesGroupOnChange()

&AtClient
// Procedure - event handler OnChange attribute FillByDocument
//
Procedure AddByReceiptInvoiceOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure // FillByDocumentOnChange()

&AtClient
// Procedure - event handler OnChange attribute FillByPricesGroup
//
Procedure AddByPriceGroupOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure // FillByPricesGroupOnChange()







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
