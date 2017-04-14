
#Region Interface

Procedure FillTimeChoiceList(FormInputField, Interval = 3600, Begin = '00010101080000', End = '00010101200000') Export
	
	TimesList = FormInputField.ChoiceList;
	TimesList.Clear();
	
	TimeList = BegOfHour(Begin);
	
	While BegOfHour(TimeList) <= BegOfHour(End) Do
		
		If Not ValueIsFilled(TimeList) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(TimeList,"DF=HH:mm");
		EndIf;
		
		TimesList.Add(TimeList, TimePresentation);
		
		TimeList = TimeList + Interval;
		
	EndDo;
	
EndProcedure

#EndRegion
