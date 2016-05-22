#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrentFolder = CommonUse.ObjectAttributesValues(Ref,
		"Description, Parent, DeletionMark");
	
	If IsNew() Or CurrentFolder.Parent <> Parent Then
		// Check right "Adding".
		If Not FileOperationsService.IsRight("FoldersUpdate", Parent) Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'You haven''t enough rights to add subfolders in file folder ""%1"".'"),
				String(Parent));
		EndIf;
	EndIf;
	
	If DeletionMark AND CurrentFolder.DeletionMark <> True Then
		
		// Check right "Deletion mark".
		If Not FileOperationsService.IsRight("FoldersUpdate", Ref) Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'You haven''t enough rights to change file folders ""%1"".'"),
				String(Ref));
		EndIf;
	EndIf;
	
	If DeletionMark <> CurrentFolder.DeletionMark AND Not Ref.IsEmpty() Then
		// Select the files, and try to mark them for deletion.
		Query = New Query;
		Query.Text = 
			"SELECT
			|	Files.Ref,
			|	Files.IsEditing
			|FROM
			|	Catalog.Files AS Files
			|WHERE
			|	Files.FileOwner = &Ref";
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			If Not Selection.IsEditing.IsEmpty() Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
				                     NStr("en = 'Folder %1 can''t be deleted, so. it it contains file ""%2"" locked for editing.'"),
				                     String(Ref),
				                     String(Selection.Ref));
			EndIf;

			FileObject = Selection.Ref.GetObject();
			FileObject.Lock();
			FileObject.SetDeletionMark(DeletionMark);
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("PreviousIsNew", IsNew());
	
	If Not IsNew() Then
		
		If Description <> CurrentFolder.Description Then // folder is renamed
			FolderWorkingDirectory         = FileOperationsServiceServerCall.FolderWorkingDirectory(Ref);
			ParentFolderWorkingCatalog = FileOperationsServiceServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			If ParentFolderWorkingCatalog <> "" Then
				
				// Add a slash at the end in case it is absent.
				ParentFolderWorkingCatalog = CommonUseClientServer.AddFinalPathSeparator(
					ParentFolderWorkingCatalog);
				
				FolderWorkingDirectoryInheritedFormer = ParentFolderWorkingCatalog
					+ CurrentFolder.Description + CommonUseClientServer.PathSeparator();
					
				If FolderWorkingDirectoryInheritedFormer = FolderWorkingDirectory Then
					
					NewWorkingDirectoryOfFolder = ParentFolderWorkingCatalog
						+ Description + CommonUseClientServer.PathSeparator();
					
					FileOperationsServiceServerCall.SaveFolderWorkingDirectory(Ref, NewWorkingDirectoryOfFolder);
				EndIf;
			EndIf;
		EndIf;
		
		If Parent <> CurrentFolder.Parent Then // Moved the folder in another folder.
			FolderWorkingDirectory               = FileOperationsServiceServerCall.FolderWorkingDirectory(Ref);
			ParentFolderWorkingCatalog       = FileOperationsServiceServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			WorkingDirectoryOfNewFolderParent = FileOperationsServiceServerCall.FolderWorkingDirectory(Parent);
			
			If ParentFolderWorkingCatalog <> "" OR WorkingDirectoryOfNewFolderParent <> "" Then
				
				FolderWorkingDirectoryInheritedFormer = ParentFolderWorkingCatalog;
				
				If ParentFolderWorkingCatalog <> "" Then
					FolderWorkingDirectoryInheritedFormer = ParentFolderWorkingCatalog
						+ CurrentFolder.Description + CommonUseClientServer.PathSeparator();
				EndIf;
				
				// Working directory forms automatically from parent.
				If FolderWorkingDirectoryInheritedFormer = FolderWorkingDirectory Then
					If WorkingDirectoryOfNewFolderParent <> "" Then
						
						NewWorkingDirectoryOfFolder = WorkingDirectoryOfNewFolderParent
							+ Description + CommonUseClientServer.PathSeparator();
						
						FileOperationsServiceServerCall.SaveFolderWorkingDirectory(Ref, NewWorkingDirectoryOfFolder);
					Else
						FileOperationsServiceServerCall.ClearWorkingDirectory(Ref);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.PreviousIsNew Then
		FolderWorkingDirectory = FileOperationsServiceServerCall.FolderWorkingDirectory(Parent);
		If FolderWorkingDirectory <> "" Then
			
			// Add a slash at the end in case it is absent.
			FolderWorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(
				FolderWorkingDirectory);
			
			FolderWorkingDirectory = FolderWorkingDirectory
				+ Description + CommonUseClientServer.PathSeparator();
			
			FileOperationsServiceServerCall.SaveFolderWorkingDirectory(Ref, FolderWorkingDirectory);
		EndIf;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	CreationDate = CurrentSessionDate();
	Responsible = Users.CurrentUser();
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	FoundProhibitedCharArray = CommonUseClientServer.FindProhibitedCharsInFileName(Description);
	If FoundProhibitedCharArray.Count() <> 0 Then
		Cancel = True;
		
		Text = NStr("en = 'Folder description contains not allowed symbols ( \ / : * ? "" < > | .. )'");
		CommonUseClientServer.MessageToUser(Text, ThisObject, "Description");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf