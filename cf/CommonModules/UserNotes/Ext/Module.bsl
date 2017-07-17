
////////////////////////////////////////////////////////////////////////////////
// Subsystem "User notes".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Marks notes for deletion which are associated with the object to be deleted.
Procedure MarkToDeleteSubjectNotes(Source, Cancel) Export
	If Not Source.DeletionMark Then
		Return;
	EndIf;
	
	QueryText =
	"SELECT
	|	Notes.Ref AS Ref
	|FROM
	|	Catalog.Notes AS Notes
	|WHERE
	|	Notes.DeletionMark = FALSE
	|	AND Notes.Subject = &Subject";
	
	Query = New Query(QueryText);
	Query.SetParameter("Subject", Source.Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NoteObject = Selection.Ref.GetObject();
		NoteObject.SetDeletionMark(True, False);
		NoteObject.AdditionalProperties.Insert("NoteDeletionMark", True);
		Try
			NoteObject.Write();
		Except
			ErrorText = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("en='User notes.Set deletion mark';ru='Заметки пользователя.Установка пометки удаления'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error, NoteObject.Metadata(), NoteObject.Ref, ErrorText);
		EndTry;
	EndDo;
EndProcedure

#EndRegion
