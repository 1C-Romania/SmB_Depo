&AtClient
Var ParametersOfLongOperationClient;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Parameters.ThisIsAdditionalInformation Then
		Items.TypesProperties.CurrentPage = Items.Information;
		Title = NStr("en = 'Change the additional information setting'");
	Else
		Items.TypesProperties.CurrentPage = Items.Attribute;
	EndIf;
	
	If ValueIsFilled(Parameters.PropertySet) Then
		Items.AttributeKinds.CurrentPage = Items.KindCommonAttributesValues;
		Items.KindsOfInformation.CurrentPage  = Items.KindGeneralInformationValues;
		
		If ValueIsFilled(Parameters.AdditionalValuesOwner) Then
			SinglePropertyWithCommonListOfValues = 1;
		Else
			SeparatePropertyWithSeparateValuesList = 1;
		EndIf;
	Else
		Items.AttributeKinds.CurrentPage = Items.CommonAttributeKind;
		Items.KindsOfInformation.CurrentPage  = Items.CommonInformationKind;
		
		CommonProperty = 1;
	EndIf;
	
	Property = Parameters.Property;
	CurrentSetOfProperties = Parameters.CurrentSetOfProperties;
	ThisIsAdditionalInformation = Parameters.ThisIsAdditionalInformation;
	
	Items.IndividualValuesAttributeComment.Title =
		StringFunctionsClientServer.PlaceParametersIntoString(
			Items.IndividualValuesAttributeComment.Title, CurrentSetOfProperties);
	
	Items.CommonAttributesValuesComment.Title =
		StringFunctionsClientServer.PlaceParametersIntoString(
			Items.CommonAttributesValuesComment.Title, CurrentSetOfProperties);
	
	Items.SeparateDataValuesComment.Title =
		StringFunctionsClientServer.PlaceParametersIntoString(
			Items.SeparateDataValuesComment.Title, CurrentSetOfProperties);
	
	Items.GeneralInformationValuesComment.Title =
		StringFunctionsClientServer.PlaceParametersIntoString(
			Items.GeneralInformationValuesComment.Title, CurrentSetOfProperties);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseEnd", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure KindOnChange(Item)
	
	KindAtServerOnChange(Item.Name);
	
EndProcedure

&AtServer
Procedure KindAtServerOnChange(ItemName)
	
	SinglePropertyWithCommonListOfValues = 0;
	SeparatePropertyWithSeparateValuesList = 0;
	CommonProperty = 0;
	
	ThisObject[Items[ItemName].DataPath] = 1;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseEnd();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure WriteAndCloseEnd(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If SeparatePropertyWithSeparateValuesList = 1 Then
		WriteBegin();
	Else
		WriteCompletion(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteBegin()
	
	Status(NStr("en = 'Property setting change is executed. Please, wait'"));
	
	OpenProperty = WriteAtServer();
	
	If OpenProperty <> NULL Then
		WriteCompletion(OpenProperty);
	Else
		ParametersOfLongOperationClient = New Structure;
		ParametersOfLongOperationClient.Insert("IdleHandlerParameters");
		
		LongActionsClient.InitIdleHandlerParameters(
			ParametersOfLongOperationClient.IdleHandlerParameters);
		
		AttachIdleHandler("Attachable_CheckOutChangingConfigurationProperties",
			ParametersOfLongOperationClient.IdleHandlerParameters.MinInterval, True);
		
		ParametersOfLongOperationClient.Insert("LongOperationForm",
			LongActionsClient.OpenLongOperationForm(
				ThisObject, ParametersOfLongOperation.JobID));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckPropertySettingChange()
	
	Result = NULL;
	
	Try
		If ParametersOfLongOperationClient.LongOperationForm.IsOpen()
		   AND ParametersOfLongOperationClient.LongOperationForm.JobID
		         = ParametersOfLongOperation.JobID Then
			
			Result = JobCompleted(ParametersOfLongOperation);
			If Result = NULL Then
				
				LongActionsClient.UpdateIdleHandlerParameters(
					ParametersOfLongOperationClient.IdleHandlerParameters);
				
				AttachIdleHandler(
					"Attachable_CheckOutChangingConfigurationProperties",
					ParametersOfLongOperationClient.IdleHandlerParameters.CurrentInterval,
					True);
			Else
				LongActionsClient.CloseLongOperationForm(
					ParametersOfLongOperationClient.LongOperationForm);
			EndIf;
		EndIf;
	Except
		LongActionsClient.CloseLongOperationForm(
			ParametersOfLongOperationClient.LongOperationForm);
		Raise;
	EndTry;
	
	If Result <> NULL Then
		WriteCompletion(Result);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(ParametersOfLongOperation)
	
	If LongActions.JobCompleted(ParametersOfLongOperation.JobID) Then
		Return GetFromTempStorage(ParametersOfLongOperation.StorageAddress);
	EndIf;
	
	Return NULL;
	
EndFunction

&AtClient
Procedure WriteCompletion(OpenProperty)
	
	Modified = False;
	
	Notify("Writing_AdditionalAttributesAndInformation",
		New Structure("Ref", Property), Property);
	
	Notify("Writing_AdditionalAttributesAndInformationSets",
		New Structure("Ref", CurrentSetOfProperties), CurrentSetOfProperties);
	
	NotifyChoice(OpenProperty);
	
EndProcedure

&AtServer
Function WriteAtServer()
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("Property", Property);
	ProcedureParameters.Insert("CurrentSetOfProperties", CurrentSetOfProperties);
	
	JobDescription = NStr("en = 'Additional property setting modification'");
	
	Result = LongActions.ExecuteInBackground(
		UUID,
		"ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.ChangePropertiesConfiguration",
		ProcedureParameters,
		JobDescription);
		
	If Result.JobCompleted Then
		Return GetFromTempStorage(Result.StorageAddress);
	EndIf;
	
	ParametersOfLongOperation = Result;
	
	Return NULL;
	
EndFunction

#EndRegion
