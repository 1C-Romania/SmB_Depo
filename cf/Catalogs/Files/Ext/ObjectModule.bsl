#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event data processor BeforeWrite.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(FileOwner) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Owner in file is
		|not filled in ""%1"".';ru='Не заполнен
		|владелец в файле ""%1"".'"),
			Description);
		
		If InfobaseUpdate.InfobaseUpdateInProgress() Then
			
			WriteLogEvent(
				NStr("en='Files. An error occurred when writing the file while updating IB';ru='Файлы.Ошибка записи файла при обновлении ИБ'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				Ref,
				ErrorDescription);
		Else
			Raise ErrorDescription;
		EndIf;
		
	EndIf;
	
	If IsNew() Then
		// Check right "Adding".
		If Not FileOperationsService.IsRight("FilesAdd", FileOwner) Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Insufficient rights to add files to folder ""%1"".';ru='Недостаточно прав для добавления файлов в папку ""%1"".'"),
				String(FileOwner));
		EndIf;
	Else
		
		HasDeletionMarkInInfobase = DeletionMarkInIB();
		DeletionMarkIsMarked = DeletionMark AND Not HasDeletionMarkInInfobase;
		DeletionMarkChanged = (DeletionMark <> HasDeletionMarkInInfobase);
		
		DigitallySignedObjectRecord = False;
		If AdditionalProperties.Property("DigitallySignedObjectRecord") Then
			DigitallySignedObjectRecord = AdditionalProperties.DigitallySignedObjectRecord;
		EndIf;	
		
		// Allow to put deletion mark on a signed file.
		If Not PrivilegedMode() AND DigitallySignedObjectRecord <> True AND Not DeletionMarkIsMarked Then
			
			If ValueIsFilled(Ref) Then
				
				AttributesStructure = CommonUse.ObjectAttributesValues(Ref, "DigitallySigned, Encrypted");
				RefDigitallySigned = AttributesStructure.DigitallySigned;
				RefEncrypted = AttributesStructure.Encrypted;
				
				If DigitallySigned AND RefDigitallySigned Then
					Raise NStr("en='Signed file cannot be edited.';ru='Подписанный файл нельзя редактировать.'");
				EndIf;	
				
				If Encrypted AND RefEncrypted AND DigitallySigned AND Not RefDigitallySigned Then
					Raise NStr("en='Encrypted file cannot be signed.';ru='Зашифрованный файл нельзя подписывать.'");
				EndIf;	
				
			EndIf;	
			
		EndIf;	
		
		If Not CurrentVersion.IsEmpty() Then
			
			CurrentVersionAttributes = CommonUse.ObjectAttributesValues(
				CurrentVersion, "FullDescr");
			
			// Check attachment file name equality and its current version.
			// If the names are different - version name must be the same as of the card with file.
			If CurrentVersionAttributes.FullDescr <> FullDescr Then
				Object = CurrentVersion.GetObject();
				If Object <> Undefined AND Object.Ref <> Undefined Then
					LockDataForEdit(Object.Ref);
					SetPrivilegedMode(True);
					Object.FullDescr = FullDescr;
					// IN order to prevent the CopyFileVersionAttributesToFile subscription from activiation.
					Object.AdditionalProperties.Insert("FileRenaming", True);
					Object.Write();
					SetPrivilegedMode(False);
				EndIf;
			EndIf;
			
		EndIf;
		
		If DeletionMarkChanged Then
			
			// Check right "Deletion mark".
			If Not FileOperationsService.IsRight("FileDeletionMark", FileOwner) Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Insufficient rights to mark files for deletion in folder ""%1"".';ru='Недостаточно прав для пометки файлов на удаление в папке ""%1"".'"),
					String(FileOwner));
			EndIf;
			
			// Try set deletion mark.
			If DeletionMarkIsMarked AND Not IsEditing.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Cannot delete
		|file ""%1"", so. it is locked for editing by user ""%2"".';ru='Нельзя удалить файл ""%1"",
		|т.к. он занят для редактирования пользователем ""%2""'"),
					FullDescr,
					String(IsEditing) );
			EndIf;
			
		EndIf;
		
		VIBDescription = VIBDescription();
		If FullDescr <> VIBDescription Then 
			If Not IsEditing.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='File can not be
		|renamed ""%1"", so. it is locked for editing by user ""%2"".';ru='Нельзя переименовать файл ""%1"",
		|т.к. он занят для редактирования пользователем ""%2"".'"),
					VIBDescription,
					String(IsEditing));
			EndIf;
		EndIf;
		
	EndIf;
	
	Description = TrimAll(FullDescr);
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	
	If IsNew() Then
		CreationDate = CurrentSessionDate();
		StoreVersions = True;
		PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(Undefined);
		
		Author = Users.CurrentUser();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the current value of the deletion mark in infobase.
Function DeletionMarkInIB()
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Files.DeletionMark
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.Ref = &Ref";

	Query.SetParameter("Ref", Ref);

	Result = Query.Execute();

	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.DeletionMark;
	EndIf;	
	
	Return Undefined;
EndFunction

// Returns the current description value in infobase.
Function VIBDescription()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Files.FullDescr
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.FullDescr;
	EndIf;
	
	Return Undefined;	
	
EndFunction

#EndRegion

#EndIf
