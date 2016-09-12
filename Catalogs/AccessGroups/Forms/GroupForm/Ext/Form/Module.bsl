
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AccessGroups)
	     
	 OR AccessParameters("Update", Metadata.Catalogs.AccessGroups,
	         "Ref").RestrictionByCondition Then
		
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CurrentObject.Ref = Catalogs.AccessGroups.ParentOfPersonalAccessGroups(True) Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	PersonalAccessGroupsName = Undefined;
	
	ParentOfPersonalAccessGroups = Catalogs.AccessGroups.ParentOfPersonalAccessGroups(
		True, PersonalAccessGroupsName);
	
	If Object.Ref <> ParentOfPersonalAccessGroups
	   AND Object.Description = PersonalAccessGroupsName Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='This description is reserved.';ru='Это наименование зарезервировано.'"),
			,
			"Object.Description",
			,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion



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
