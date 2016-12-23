
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// Function returns the value array containing tabular section units
//
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow IN Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction // FillArrayByTabularSectionAtClient()

&AtClient
// Adds array items to the tabular section.
// Preliminary check whether this item is in the tabular section.
//
Procedure AddItemsIntoTabularSection(ItemArray)
	
	If Not TypeOf(ItemArray) = Type("Array") 
		OR Not ItemArray.Count() > 0 Then 
		
		Return;
		
	EndIf;
	
	For Each ArrayElement IN ItemArray Do
		
		If Object.PriceKinds.FindRows(New Structure("Ref", ArrayElement)).Count() > 0 Then
			
			MessageText = NStr("en = 'Item [" + ArrayElement + "] is present in the filter.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Continue;
			
		EndIf;
		
		NewRow 		= Object.PriceKinds.Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure //AddItemsIntoTabularSection()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ArrayPriceKinds") Then
		
		For Each ItemOfArray IN Parameters.ArrayPriceKinds Do
				
			NewRow = Object.PriceKinds.Add();
			NewRow.Ref = ItemOfArray.Ref;
				
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Not TypeOf(ValueSelected) = Type("Array") Then
		
		ChoiceValue 		= ValueSelected;
		ValueSelected	= New Array;
		ValueSelected.Add(ChoiceValue);
		
	EndIf;
	
	AddItemsIntoTabularSection(ValueSelected);
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

&AtClient
// Procedure - command handler OK.
//
Procedure OK(Command)
	
	NotifyChoice(FillArrayByTabularSectionAtClient("PriceKinds"));
	
EndProcedure // Ok()

&AtClient
// Procedure - Selection command handler.
//
Procedure Pick(Command)
	
	OpenForm("Catalog.PriceKinds.ChoiceForm", New Structure("Multiselect, ChoiceMode, CloseOnChoice", True, True, False), ThisForm);
	
EndProcedure // Pick()














