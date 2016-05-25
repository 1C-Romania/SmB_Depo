
&AtClient
Var PriceKindOnOpen;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PriceKind = Parameters.PriceKind;
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
// The procedure implements
// - initializing the form parameters.
//
&AtClient
Procedure OnOpen(Cancel)
	
	PriceKindOnOpen = PriceKind;
	
EndProcedure // OnOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	Cancel = False;
	If RefillPrices AND Not ValueIsFilled(PriceKind) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Fill in Price type has not been selected!'");
		Message.Field = "PriceKind";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not Cancel Then
		If PriceKindOnOpen <> PriceKind OR RefillPrices Then
			WereMadeChanges = True;
		Else
			WereMadeChanges = False;
		EndIf;
		StructureOfFormAttributes = New Structure;
		StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
		StructureOfFormAttributes.Insert("RefillPrices", RefillPrices);
		StructureOfFormAttributes.Insert("PriceKind", PriceKind);
		Close(StructureOfFormAttributes);
	EndIf;
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of the PriceKind input field.
//
&AtClient
Procedure PriceKindOnChange(Item)
	
	If ValueIsFilled(PriceKind) Then
		If PriceKindOnOpen <> PriceKind Then
			RefillPrices = True;
		EndIf;
	EndIf;
	
EndProcedure // PriceKindOnChange()



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
