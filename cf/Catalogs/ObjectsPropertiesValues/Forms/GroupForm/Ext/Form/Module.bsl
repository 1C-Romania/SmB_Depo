
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Parameters.FillingValues.Property("Description") Then
		
		Object.Description = Parameters.FillingValues.Description;
	EndIf;
	
	If Not Parameters.HideOwner Then
		Items.Owner.Visible = True;
	EndIf;
	
	SetTitle();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetTitle();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetTitle()
	
	AttributeValues = CommonUse.ObjectAttributesValues(
		Object.Owner, "Title, ValueFormHeader");
	
	PropertyName = TrimAll(AttributeValues.ValueFormHeader);
	
	If Not IsBlankString(PropertyName) Then
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 (%2)';ru='%1 (%2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 (Creating)';ru='%1 (Создание)'"), PropertyName);
		EndIf;
	Else
		PropertyName = String(AttributeValues.Title);
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 (%2 property value group)';ru='%1 (Группа значений свойства %2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Group of the %1 property values (Creation)';ru='Группа значений свойства %1 (Создание)'"), PropertyName);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
