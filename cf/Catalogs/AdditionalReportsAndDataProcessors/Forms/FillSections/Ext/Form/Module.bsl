
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Filling available section table.
	
	UsedSections = New Array;
	If Parameters.DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor Then
		UsedSections = AdditionalReportsAndDataProcessors.AdditionalDataProcessorSections();
	Else
		UsedSections = AdditionalReportsAndDataProcessors.AdditionalReportsSections();
	EndIf;
	
	Desktop = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
	
	For Each Section IN UsedSections Do
		NewRow = Sections.Add();
		If Section = Desktop Then
			NewRow.Section = Catalogs.MetadataObjectIDs.EmptyRef();
		Else
			NewRow.Section = CommonUse.MetadataObjectID(Section);
		EndIf;
		NewRow.Presentation = AdditionalReportsAndDataProcessors.PresentationOfSection(NewRow.Section);
	EndDo;
	
	Sections.Sort("Presentation Asc");
	
	// Enabling sections
	
	For Each ItemOfList IN Parameters.Sections Do
		FoundString = Sections.FindRows(New Structure("Section", ItemOfList.Value));
		If FoundString.Count() = 1 Then
			FoundString[0].Used = True;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New ValueList;
	
	For Each SectionItem IN Sections Do
		If SectionItem.Used Then
			ChoiceResult.Add(SectionItem.Section);
		EndIf;
	EndDo;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion














