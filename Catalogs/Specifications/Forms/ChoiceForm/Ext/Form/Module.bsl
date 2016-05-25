

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsAndServicesType;
			
			If (OwnerType = Enums.ProductsAndServicesTypes.Operation
				OR OwnerType = Enums.ProductsAndServicesTypes.WorkKind
				OR OwnerType = Enums.ProductsAndServicesTypes.Service
				OR (NOT Constants.FunctionalOptionUseSubsystemProduction.Get() AND OwnerType = Enums.ProductsAndServicesTypes.InventoryItem)
				OR (NOT Constants.FunctionalOptionUseWorkSubsystem.Get() AND OwnerType = Enums.ProductsAndServicesTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en = 'For the items of the %EtcProductsAndServices% type the specification is not specified!'");
				LabelText = StrReplace(LabelText, "%EtcProductsAndServices%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure


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
