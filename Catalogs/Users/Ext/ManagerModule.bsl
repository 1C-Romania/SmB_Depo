#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("Service");
	NotEditableAttributes.Add("InfobaseUserID");
	NotEditableAttributes.Add("ServiceUserID");
	NotEditableAttributes.Add("InfobaseUserProperties");
	
	Return NotEditableAttributes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data import from the file

// Prohibits data import in this catalog from subsystem "DataLoadFromFile" Batch data import in this catalog is unsafe
// 
Function UseDataLoadFromFile() Export
	Return False;
EndFunction

#EndRegion

#Region ServiceInterface

// Returns catalog attributes which form
//  the natural key for the catalog items.
//
// Return value: Array(Row) - is the array of names of attributes
//  which form the natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Description");
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("NotValid") Then
		Parameters.Filter.Insert("NotValid", False);
	EndIf;
	
	If Not Parameters.Filter.Property("Service") Then
		Parameters.Filter.Insert("Service", False);
	EndIf;
	
EndProcedure

#EndRegion
