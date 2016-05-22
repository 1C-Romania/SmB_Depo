////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the form for editing the additional attributes.
//
// Parameters:
//  Form        - ManagedForm, preconfigured in procedure.
//                PropertiesManagement.OnCreateAtServer()
//
Procedure EditContentOfProperties(Form, Ref = Undefined) Export
	
	Sets = Form.Properties_AdditionalObjectAttributesSets;
	
	If Sets.Count() = 0
	 OR Not ValueIsFilled(Sets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Failed to receive the additional object attributes.
			           |
			           |Perhaps, the necessary attributes have not been filled for the document.'"));
	
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ShowAdditionalAttributes");
		
		OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", FormParameters);
		
		ParametersOfTransition = New Structure;
		ParametersOfTransition.Insert("Set", Sets[0].Value);
		ParametersOfTransition.Insert("Property", Undefined);
		ParametersOfTransition.Insert("ThisIsAdditionalInformation", False);
		
		LengthBeginning = StrLen("AdditionalAttributeValue_");
		If Upper(Left(Form.CurrentItem.Name, LengthBeginning)) = Upper("AdditionalAttributeValue_") Then
			
			IDSet   = StrReplace(Mid(Form.CurrentItem.Name, LengthBeginning +  1, 36), "x","-");
			PropertyID = StrReplace(Mid(Form.CurrentItem.Name, LengthBeginning + 38, 36), "x","-");
			
			If StringFunctionsClientServer.ThisIsUUID(Lower(IDSet)) Then
				ParametersOfTransition.Insert("Set", IDSet);
			EndIf;
			
			If StringFunctionsClientServer.ThisIsUUID(Lower(PropertyID)) Then
				ParametersOfTransition.Insert("Property", PropertyID);
			EndIf;
		EndIf;
		
		Notify("Transition_SetsOfAdditionalDetailsAndInformation", ParametersOfTransition);
	EndIf;
	
EndProcedure

// Defines that the specified event is the event related to the change of attributes set.
// 
// Return value:
//  Boolean - if True, this notification is about changing the attributes
//            set, and you need to handle it in a form.
//
Function ProcessAlerts(Form, EventName, Parameter) Export
	
	If Not Form.Properties_UseProperties
	 OR Not Form.Properties_UseAdditAttributes Then
		
		Return False;
	EndIf;
	
	If EventName = "Writing_AdditionalAttributesAndInformationSets" Then
		Return Form.Properties_AdditionalObjectAttributesSets.FindByValue(Parameter.Ref) <> Undefined;
		
	ElsIf EventName = "Writing_AdditionalAttributesAndInformation" Then
		Filter = New Structure("Property", Parameter.Ref);
		Return Form.Properties_AdditionalAttributesDescription.FindRows(Filter).Count() > 0;
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
