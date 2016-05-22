#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("AuthorizationObject");
	NotEditableAttributes.Add("SetRolesDirectly");
	NotEditableAttributes.Add("InfobaseUserID");
	NotEditableAttributes.Add("ServiceUserID");
	NotEditableAttributes.Add("InfobaseUserProperties");
	NotEditableAttributes.Add("DeletePassword");
	
	Return NotEditableAttributes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data import from the file

// Prohibits to import data to this catalog from subsystem "DataLoadFromFile".
// Batch data import in this catalog is unsafe.
//
Function UseDataLoadFromFile() Export
	Return False;
EndFunction


#EndRegion

#EndIf

#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("NotValid") Then
		Parameters.Filter.Insert("NotValid", False);
	EndIf;
	
EndProcedure

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ObjectForm" AND Parameters.Property("AuthorizationObject") Then
		
		StandardProcessing = False;
		SelectedForm = "ItemForm";
		
		FoundExternalUser = Undefined;
		CanAddExternalUser = False;
		
		AuthorizationObjectInUse = UsersServiceServerCall.AuthorizationObjectInUse(
			Parameters.AuthorizationObject,
			,
			FoundExternalUser,
			CanAddExternalUser);
		
		If AuthorizationObjectInUse Then
			Parameters.Insert("Key", FoundExternalUser);
			
		ElsIf CanAddExternalUser Then
			
			Parameters.Insert(
				"NewExternalUserAuthorizationObject", Parameters.AuthorizationObject);
		Else
			ErrorAsWarningDescription =
				NStr("en = 'Permission on input to the application was not provided.'");
				
			Raise ErrorAsWarningDescription;
		EndIf;
		
		Parameters.Delete("AuthorizationObject");
	EndIf;
	
EndProcedure

#EndRegion
