
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

#EndRegion

#Region FormItemEventHadlers

&AtClient
Procedure DocumentKindOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

&AtClient
Procedure NumberOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

&AtClient
Procedure IssueDateOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Function GenerateDescription(DocumentKind, Number, IssueDate)
	
	TextName = NStr("ru='%DocumentKind% № %Number% %IssueDate%'; en='%DocumentKind% # %Number% %IssueDate%'");
	TextName = StrReplace(TextName, "%DocumentKind%", TrimAll(String(DocumentKind)));
	TextName = StrReplace(TextName, "%Number%", TrimAll(Number));
	TextName = StrReplace(TextName, "%IssueDate%", ?(ValueIsFilled(IssueDate), NStr("ru = 'от '; en = 'from '") + TrimAll(String(Format(IssueDate, "DF=dd.MM.yyyy"))), ""));
	
	Return TextName;
	
EndFunction

#EndRegion
