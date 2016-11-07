#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() = 1 Then
		Folder = Get(0).Folder;
		Path = Get(0).Path;
		
		If IsBlankString(Path) Then
			Return;
		EndIf;						
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FileFolders.Ref,
			|	FileFolders.Description
			|FROM
			|	Catalog.FileFolders AS FileFolders
			|WHERE
			|	FileFolders.Parent = &Ref";
		
		Query.SetParameter("Ref", Folder);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			WorkingDirectory = Path;
			// Add a slash in the end if it is absent - same type that already was - as it is necessary on the client
    // and BeforeWrite is executed on server.
			WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(WorkingDirectory);
			
			WorkingDirectory = WorkingDirectory + Selection.Description;
			WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(WorkingDirectory);
			
			FileOperationsServiceServerCall.SaveFolderWorkingDirectory(
				Selection.Ref, WorkingDirectory);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf