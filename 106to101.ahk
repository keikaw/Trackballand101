#Requires AutoHotkey v2.0
;logFile := A_ScriptDir "\debug_log.txt" ; スクリプトと同じディレクトリにログファイルを作成
logAdd(str) {
	;FileAppend(str ,logFile)
}
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
CoordMode "Caret", "Screen"
CoordMode "Menu", "Screen"

;-------------------------------------------------------------------------------
; Scrolling Mode for Track ball
; 進むボタン長押しで有効化
; 進むボタン短押しで解除
;-------------------------------------------------------------------------------
Global IsScrolling := false
Global initial_pos_x := 0
Global initial_pos_y := 0
Global sekibun_x := 0
Global sekibun_y := 0
Global before_target := 0 ; 0:flat 1:right 2:left 3:down 4:up

; スクロールモード時のマウスカーソル監視
ChkMouseMove() {
	Global IsScrolling
	logAdd("30ms:" . "`n")
	;スクロールモードであれば スクロール量に応じてWheeDown/Up操作を行う
	if ( IsScrolling ) {
		MouseGetPos &pos_x,&pos_y
		BlockInput "MouseMove"
		; マウスカーソルを有効化した直後の位置に戻す
		MouseMove initial_pos_x,initial_pos_y,0
		movex := pos_x - initial_pos_x
		movey := pos_y - initial_pos_y

		logAdd("move: " . movex . " " . movey . "`n")
		SendWheelFunc(movex, movey)

		BlockInput "MouseMoveOff"
		; カーソル監視を継続
		SetTimer ChkMouseMove, -100
	}
}

; カーソルを隠す
HideCursorFn() {
    DllCall("ShowCursor", "Int", 0) ; 0 を渡すとカウンターをデクリメント
}

; カーソルを表示する
ShowCursorFn() { ; 関数名が既存のAutoHotkeyコマンドと重複しないように注意 (ShowCursorFnなど)
    DllCall("ShowCursor", "Int", 1) ; 1 を渡すとカウンターをインクリメント
}


; Wheelのイベントを送信
SendWheelFunc(x,y) {
	Global sekibun_x
	Global sekibun_y
	Global before_target	; 0:flat 1:right 2:left 3:down 4:up

	new_target := CheckTarget(x,y)

	if(new_target == 0 ) {
		new_target := before_target	;方向を維持
		logAdd("flat:" . sekibun_x . " "  . sekibun_y . "`n")
	} else if (new_target == before_target) {
		if ( ( new_target == 1) || ( new_target == 2) ) {
			sekibun_x := sekibun_x + x
			sekibun_y := 0
		} else {
			sekibun_y := sekibun_y + y
			sekibun_x := 0
		}
	} else {
		before_target := new_target	;方向の変化が発生
		if ( ( new_target == 1) || ( new_target == 2) ) {
			sekibun_x := sekibun_x + x
			sekibun_y := 0
		} else {
			sekibun_y := sekibun_y + y
			sekibun_x := 0
		}
	}

	if (new_target==0) {
		logAdd("error: new_target error" . "`n")
	} else if (new_target==1) {
		if( abs(sekibun_x) > (20*20) ) {
			SendInputWheelRight(20)
			sekibun_x := sekibun_x - (20*20)
		}
		SendInputWheelRight(Floor(abs(sekibun_x)/20))
		sekibun_x := sekibun_x - (Floor(abs(sekibun_x)/20) * 20)
	} else if (new_target==2) {
		if( abs(sekibun_x) > (20*20) ) {
			SendInputWheelLeft(20)
			sekibun_x := sekibun_x + (20*20)
		}
		SendInputWheelLeft(Floor(abs(sekibun_x)/20))
		sekibun_x := sekibun_x + (Floor(abs(sekibun_x)/20) * 20)
	} else if (new_target==3) {
		if( abs(sekibun_y) > (20*2) ) {
			SendInputWheelDown(20)
			sekibun_y := sekibun_y - (20*2)
		}
		SendInputWheelDown(Floor(abs(sekibun_y)/2))
		sekibun_y := sekibun_y - (Floor(abs(sekibun_y)/2) * 2)
	} else {
		if( abs(sekibun_y) > (20*2) ) {
			SendInputWheelUp(20)
			sekibun_y := sekibun_y + (20*2)
		}
		SendInputWheelUp(Floor(abs(sekibun_y)/2))
		sekibun_y := sekibun_y + ((Floor(abs(sekibun_y)/2)) * 2)
	}
}

CheckTarget(x,y) {
	logAdd("CheckTarget:" . x . " " . y )
	if ( (x == 0) && (y == 0) ) {
		return 0 ;flat
	}
	if ( (abs(x) - abs(y)) > 0 ) {
		if ( x > 0 ) {
			return 1 ;right
		}
		return 2 ;left
	} 
	if ( y > 0 ) {
		return 3 ;down
	}
	return 4 ;up
}

;CalculateAccelerationFactorX(x,y) {
;	value := 1 
;	if( (abs(x) + abs(y) ) > 5 ){
;		times := 1
;	}
;	else{
;		times := 0
;	}
;	return { times: times, value: value }
;}
;
;CalculateAccelerationFactorY(x,y) {
;	absx := abs(x)
;	absy := abs(y)
;	sum := Floor(absx+absy)
;
;	value := 1 
;	if( sum > 20 ) {
;		times := 20
;	}
;	else if( sum > 5 ){
;		times := 1
;	}
;	else{
;		times := 0
;	}
;	return { times: times, value: value }
;}

SendInputWheelRight(times) {
	if( times == 0 ) {
		return
	}
	num := times
	str := "{WheelRight " . num . "}"
	loop 1 {
		SendEvent(str)
	}
}
SendInputWheelLeft(times) {
	if( times == 0 ) {
		return
	}
	num := times
	str := "{WheelLeft " . num . "}"
	loop 1 {
		SendEvent(str)
	}
}
SendInputWheelUp(times) {
	if( times == 0 ) {
		return
	}
	num := times
	str := "{WheelUp " . num . "}"
	loop 1 {
		SendEvent(str)
	}
}
SendInputWheelDown(times) {
	if( times == 0 ) {
		return
	}
	num := times
	str := "{WheelDown " . num . "}"
	loop 1 {
		SendEvent(str)
	}
}

disableToolTip() {
	ToolTip
}

; マウスの進むボタン
XButton2:: {
	Global IsScrolling
	; 進むボタンが押された瞬間（長押し判定用）
	if KeyWait("XButton2","T0.5") 
	{
		;BlockInput "MouseMoveOff"
		if ( IsScrolling == true ) {
			; スクロールモードを解除
			ToolTip "disable scroll"
			global IsScrolling := false
			; 1秒後にツールチップを非表示にする
			SetTimer disableToolTip, -1000
		}
		else {
			; スクロールモードでない場合は通常処理
			Send "{XButton2}"
		}
	} else {
		; 長押しされたらスクロールモードに切り替え
		ToolTip "enable scroll"
		IsScrolling := true
		; 現在のカーソル位置を保存
		MouseGetPos &pos_x,&pos_y
		global initial_pos_x := pos_x
		global initial_pos_y := pos_y
		; マウスカーソルの監視を動かす
		SetTimer ChkMouseMove, -100
		;BlockInput "MouseMove"
		;HideCursorFn()
	}
}

;-------------------------------------------------------------------------------
; 106 -> 101
;-------------------------------------------------------------------------------
#UseHook
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SC029::`        ;         半角/全角     -> `
+SC029::~       ; Shift + 半角/全角     -> ~
!SC029::SC029   ; Alt   + 半角/全角     -> 半角/全角
+2::@           ; Shift + 2         ["] -> @
+6::^           ; Shift + 6         [&] -> ^
+7::&           ; Shift + 7         ['] -> &
+8::*           ; Shift + 8         [(] -> *
+9::(           ; Shift + 9         [)] -> (
+0::)           ; Shift + 0         [ ] -> )
+-::_           ; Shift + -         [=] -> _
^::=            ;                   [^] -> =
+^::+           ; Shift + ^         [~] -> +
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 2段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@::[        ;                   [@] -> [
+@::`{      ; Shift + @         [`] -> {
[::]        ;                   [[] -> ]
+[::}       ; Shift + [         [{] -> }
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 3段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
:::'        ;                   [:] -> '
+;:::       ; Shift + ;         [+] -> :
*::"        ; Shift + :         [*] -> "
]::\        ;                   []] -> \
+]::|       ; Shift + ]         [}] -> |

