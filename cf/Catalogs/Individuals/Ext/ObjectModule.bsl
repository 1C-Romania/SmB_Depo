#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		DescriptionFullRecordSet = InformationRegisters.IndividualsDescriptionFull.CreateRecordSet();
		
		Query = New Query("SELECT
		                      |	IndividualsDescriptionFullSliceLast.Surname,
		                      |	IndividualsDescriptionFullSliceLast.Name,
		                      |	IndividualsDescriptionFullSliceLast.Patronymic
		                      |FROM
		                      |	InformationRegister.IndividualsDescriptionFull.SliceLast(, Ind = &Ind) AS IndividualsDescriptionFullSliceLast");
							  
		Query.SetParameter("Ind", Ref);
		QueryResult = Query.Execute();
		
		// Set is already written
		If Not QueryResult.IsEmpty() Then
			Return;
		EndIf;
		
		Initials = Description;
		
		Surname		= SmallBusinessServer.SelectWord(Initials);
		Name		= SmallBusinessServer.SelectWord(Initials);
		Patronymic	= SmallBusinessServer.SelectWord(Initials);

		WriteSet = DescriptionFullRecordSet.Add();
		WriteSet.Period		= ?(ValueIsFilled(BirthDate), Birthdate, '19000101');
		WriteSet.Surname	= Surname;
		WriteSet.Name		= Name;
		WriteSet.Patronymic	= Patronymic;
		
		If DescriptionFullRecordSet.Count() > 0 AND ValueIsFilled(DescriptionFullRecordSet[0].Period) Then
			
			DescriptionFullRecordSet[0].Ind = Ref;
			
			DescriptionFullRecordSet.Filter.Ind.Use			= True;
			DescriptionFullRecordSet.Filter.Ind.Value		= DescriptionFullRecordSet[0].Ind;
			DescriptionFullRecordSet.Filter.Period.Use		= True;
			DescriptionFullRecordSet.Filter.Period.Value	= DescriptionFullRecordSet[0].Period;
			If Not ValueIsFilled(WriteSet.Surname + WriteSet.Name + WriteSet.Patronymic) Then
				WriteSet.Surname	= Surname;
				WriteSet.Name		= Name;
				WriteSet.Patronymic	= Patronymic;
			EndIf;
			
			DescriptionFullRecordSet.Write(True);
			
		EndIf;	
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf