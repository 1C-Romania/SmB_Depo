
////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS
//

&AtServer
// Procedure fills the decoration with the list of products and services types
//
Procedure FillProductsAndServicesTypeLabel(ProductsAndServicesType)
	
	For Each ItemOfList IN ProductsAndServicesType Do
		
		Items.DecorationProductsAndServicesTypeContent.Title = Items.DecorationProductsAndServicesTypeContent.Title + ?(IsBlankString(Items.DecorationProductsAndServicesTypeContent.Title), "", ", ") + ItemOfList.Value;
		
	EndDo;
	
EndProcedure // FillProductsAndServicesTypeLabel()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(Object, Parameters);
	
	FillProductsAndServicesTypeLabel(Object.ProductsAndServicesType);
	
	CommonUseClientServer.SetFormItemProperty(Items, "Company", "Visible", GetFunctionalOption("MultipleCompaniesAccounting"));
	CommonUseClientServer.SetFormItemProperty(Items, "StructuralUnitSender", "Visible", GetFunctionalOption("AccountingBySeveralWarehouses"));
	CommonUseClientServer.SetFormItemProperty(Items, "StructuralUnitPayee", "Visible", GetFunctionalOption("AccountingBySeveralWarehouses"));
	
EndProcedure // OnCreateAtServer()
 



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
