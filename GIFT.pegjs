// All these helper functions are available inside of actions 
{
  var questionId = null;
  var questionTags = null;
  var defaultFormat = "moodle"; // default format - the GIFT specs say [moodle] is default, but not sure what that means for other applications
  var format = defaultFormat;
  const escapedCharacters = {
    "\\\\"  : "&&092;",
    "\\:"  : "&&058;",
    "\\#"  : "&&035;",
    "\\="  : "&&061;",
    "\\{"  : "&&123;",
    "\\}"  : "&&125;",
    "\\~"  : "&&126;",
    "\\n"  : "&&010"
  };
  function escapedCharacterDecode(text) {
    // Replace escaped characters with their original values, except for the newline character which should return a real (not escaped newline)
    return text.replace(/&&092;/g, '\\')
               .replace(/&&058;/g, ':')
               .replace(/&&035;/g, '#')
               .replace(/&&061;/g, '=')
               .replace(/&&123;/g, '{')
               .replace(/&&125;/g, '}')
               .replace(/&&126;/g, '~')
               .replace(/&&010/g, '\n');
  }
  function processAnswers(question, answers) {
    question.globalFeedback = answers.globalFeedback;
    switch(question.type) {
      case "TF":
        question.isTrue = answers.isTrue;
        question.trueFeedback = answers.feedback[0];
        question.falseFeedback = answers.feedback[1];
        break;
      case "MC":
      case "Numerical":
      case "Short":
        question.choices = answers.choices;
        break;
      case "Matching":
        question.matchPairs = answers.matchPairs;
        break;
    }
    // check for MC that's actually a short answer (all correct answers)
    if (question.type == "MC" && areAllCorrect(question.choices)) {
      question.type = "Short";
    }
    question.id = questionId;
    question.tags = questionTags;
    return question;
  }
  function areAllCorrect(choices) {
    var allAreCorrect = true;
    for (var i = 0; i < choices.length; i++) {
      allAreCorrect &= choices[i].isCorrect;
    }
    return allAreCorrect;
  }
  function removeNewLinesDuplicateSpaces(text) {
    text = text.replace(/[\n\r]/g,' '); // replace newlines with spaces
    return text.replace(/\s\s+/g,' ');
  }
  function setLastQuestionTextFormat(fmt) {
    format = fmt;
  }
  function getLastQuestionTextFormat() {
    return format;
  }
  function resetLastQuestionTextFormat() {
    format = defaultFormat;
  }
  function formattedText(format, txt) {
    let inferredFormat = (format !== null ? format : getLastQuestionTextFormat());
    let joinedText = txt.join('')
      .replace(/\r\n/g, '\n')  // replace Windows newlines with Unix newlines
      .trim();
    return {
      format:(inferredFormat), 
      text:(
          ((inferredFormat == "html") || (inferredFormat == "markdown")) ? 
            // keep whitespace and newlines for html and markdown
            escapedCharacterDecode(joinedText) :
            escapedCharacterDecode(removeNewLinesDuplicateSpaces(joinedText))
          )}
  }
}

GIFTQuestions
  = questions:(Category / Description / StandaloneQuestion / EmbeddedQuestion )+ _ __ { return questions; }

Question
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem1:QuestionStem? _ 
    '{' _
    answers:(MatchingAnswers / TrueFalseAnswer / MCAnswers / NumericalAnswerType / SingleCorrectShortAnswer / EssayAnswer ) _
    '}' _
    stem2:(
      Comment / 
      QuestionStem)?
    QuestionSeparator
  {    
    var embedded = (stem2 !== null);    
    var stem1Text = stem1 ? (stem1.text + (embedded ? " " : "")) : "";

    var format = (stem1 && stem1.format) || (stem2 && stem2.format) || "moodle";
    var text = stem1Text + ( embedded ? "_____ " + stem2.text : "");
    
    var question = {type:answers.type, title:title, stem: {format: format, text: text}, hasEmbeddedAnswers:embedded};
    question = processAnswers(question, answers);
    resetLastQuestionTextFormat();
    return question;
  }
  
// Standalone questions (no embedded answers)
StandaloneQuestion
  = MatchingQuestion
  / TrueFalseQuestion
  / EssayQuestion
  / ShortAnswerQuestion
  / NumericalQuestion
  / Question

// Embedded questions (with embedded answers)
EmbeddedQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    parts:QuestionParts
    QuestionSeparator
  {
    // Compose the stem and collect answers
    let stem = [];
    let answers = [];
    let answerIndex = -1;
    for (const part of parts) {
      if (part.type === "stem") {
        let spaceBefore = " ";
      	if (stem.length == 0 || stem[stem.length -1 ]==" ")spaceBefore= "";
        stem.push(spaceBefore + part.text + " ");
      } else {
        stem.push("__" + "(" + (answers.length + 1).toString() + ")" + "__");
        answers.push(part);
        answerIndex = answers.length;
      }
    }
    
    if (answers.length == 1) stem[answerIndex] = "______";
    
    stem = stem.reduce((a,b) => a + b);
    
    var question = {
      type: "MFI",
      title: title,
      stem: { format: getLastQuestionTextFormat(), text: stem.trim() },
      answers: answers.length > 1 ? answers: answers[0],
      hasEmbeddedAnswers: answers.length > 0
    };
    resetLastQuestionTextFormat();
    return question;
  }

MatchingQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem:QuestionStem _
    '{' _ ma:MatchingAnswers _ '}' _
    QuestionSeparator
  {
    var question = {
      type: "Matching",
      title: title,
      stem: stem,
      matchPairs: ma.matchPairs,
      globalFeedback: ma.globalFeedback,
      hasEmbeddedAnswers: false,
      id: questionId,
      tags: questionTags
    };
    resetLastQuestionTextFormat();
    questionId = null; questionTags = null;
    return question;
  }

TrueFalseQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem:QuestionStem _
    '{' _ tf:TrueFalseAnswer _ '}' _
    QuestionSeparator
  {
    var question = {
      type: "TF",
      title: title,
      stem: stem,
      isTrue: tf.isTrue,
      trueFeedback: tf.feedback[0],
      falseFeedback: tf.feedback[1],
      globalFeedback: tf.globalFeedback,
      hasEmbeddedAnswers: false,
      id: questionId,
      tags: questionTags
    };
    resetLastQuestionTextFormat();
    questionId = null; questionTags = null;
    return question;
  }

EssayQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem:QuestionStem _
    '{' _ ea:EssayAnswer _ '}' _
    QuestionSeparator
  {
    var question = {
      type: "Essay",
      title: title,
      stem: stem,
      globalFeedback: ea.globalFeedback,
      hasEmbeddedAnswers: false,
      id: questionId,
      tags: questionTags
    };
    resetLastQuestionTextFormat();
    questionId = null; questionTags = null;
    return question;
  }

ShortAnswerQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem:QuestionStem _
    '{' _ sa:SingleCorrectShortAnswer _ '}' _
    QuestionSeparator
  {
    var question = {
      type: "Short",
      title: title,
      stem: stem,
      choices: sa.choices,
      globalFeedback: sa.globalFeedback,
      hasEmbeddedAnswers: false,
      id: questionId,
      tags: questionTags
    };
    resetLastQuestionTextFormat();
    questionId = null; questionTags = null;
    return question;
  }

NumericalQuestion
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    stem:QuestionStem _
    '{' _ na:NumericalAnswerType _ '}' _
    QuestionSeparator
  {
    var question = {
      type: "Numerical",
      title: title,
      stem: stem,
      choices: na.choices,
      globalFeedback: na.globalFeedback,
      hasEmbeddedAnswers: false,
      id: questionId,
      tags: questionTags
    };
    resetLastQuestionTextFormat();
    questionId = null; questionTags = null;
    return question;
  }

Category "Category"
  = ResetIdsTags __ '$' 'CATEGORY:' _ cat:CategoryText QuestionSeparator {return {type:"Category", title:cat}}

Description "Description"
  = ResetIdsTags __
    TagComment*
    title:QuestionTitle? _
    text:QuestionStem
    QuestionSeparator
    { var question = {id: questionId, tags: questionTags, type:"Description", title:title, stem:text, hasEmbeddedAnswers:false};
      resetLastQuestionTextFormat(); 
      questionId = null; questionTags = null;
      return question }

QuestionParts
  = head:QuestionStem tail:(_ EmbeddedAnswer QuestionStem)* last:(_ EmbeddedAnswer)? {
      head.type = "stem"; // add type to head
      let result = [head];
      for (const [_, answer, stem] of tail) {
        stem.type = "stem"; // add type to stem
        result.push(answer, stem);
      }
      if (last) {
        // last is [_ , answer]
        result.push(last[1]);
      }
      return result;
    }

// QuestionStemPart
//   = RichText { return $.text; } // Use the text from RichText

EmbeddedAnswer
  = '{' _ choices:MCAnswers _ '}' { return choices; }

MatchingAnswers "{= match1 -> Match1\n...}"
  = matchPairs:Matches _ globalFeedback:GlobalFeedback? _
  { return { type: "Matching", matchPairs:matchPairs, globalFeedback:globalFeedback }; }

Matches "matches"
  = matchPairs:(Match)+  { return matchPairs }
  
Match "match"
  = _ '=' _ left:MatchRichText? _ '->' _ right:PlainText _ 
    { var matchPair = { 
        subquestion:{
          format:(left !== null ? left.format : getLastQuestionTextFormat()), 
          text:(left !== null ? left.text : "")
        }, 
        subanswer:right}; 
        return matchPair } 

///////////
TrueFalseAnswer "{T} or {F} or {TRUE} or {FALSE}"
  = isTrue:TrueOrFalseType _ 
    feedback:(Feedback? Feedback?) _
    globalFeedback:GlobalFeedback?
  { return { type:"TF", isTrue: isTrue, feedback:feedback, globalFeedback:globalFeedback}; }
  
TrueOrFalseType 
  = isTrue:(TrueType / FalseType) { return isTrue }
  
TrueType
  = ('TRUE' / 'T') {return true}

FalseType
  = ('FALSE' / 'F') {return false}

////////////////////
MCAnswers "{=correct choice ~incorrect choice ... }"
  = choices:Choices _ 
    globalFeedback:GlobalFeedback? _
  { return { type: "MC", choices:choices, globalFeedback:globalFeedback}; }

Choices "Choices"
  = choices:(Choice)+ { return choices; }
 
Choice "Choice"
  = _ choice:([=~] _ Weight? _ RichText) feedback:Feedback? _ 
    { var wt = choice[2];
      var txt = choice[4];
      var choice = { isCorrect: (choice[0] == '='), 
                     weight:wt, 
                     text: txt,
                     feedback:feedback };
      return choice } 

Weight "(weight)"
  = '%' percent:(PercentValue) '%' {
	return percent;
  }

PercentValue "(percent)"
    = percent:(!'%' .)* {
      let error = 'a value between -100 and 100'
      if (percent.length == 0) expected(error + ' (did you forget to put a value?)');
      // the !'%' shows up as a 0th element in the percent array (of arrays), so we have to join the 1th elements
	  const pct = parseFloat(percent.map(innerArray => innerArray[1]).join(""));
      if (pct >= -100 && pct <= 100) {
        return pct;
      } else {
        expected(error)
      }
    }

Feedback "(feedback)" 
  = '#' !'###' _ feedback:RichText? { return feedback }

////////////////////
EssayAnswer "Essay question { ... }"
  = '' _
    globalFeedback:GlobalFeedback? _ 
  { return { type: "Essay", globalFeedback:globalFeedback}; }

///////////////////
SingleCorrectShortAnswer "Single short answer { ... }"
  = answer:RichText _ 
    feedback:Feedback? _ 
    globalFeedback:GlobalFeedback? _
  { var choices = [];
    choices.push({isCorrect:true, text:answer, feedback:feedback, weight:null});
    return { type: "Short", choices:choices, globalFeedback:globalFeedback}; }

///////////////////
NumericalAnswerType "{#... }" // Number ':' Range / Number '..' Number / Number
  = '#' _
    numericalAnswers:NumericalAnswers _ 
    globalFeedback:GlobalFeedback? 
  { return { type:"Numerical", 
             choices:numericalAnswers, 
             globalFeedback:globalFeedback}; }

NumericalAnswers "Numerical Answers"
  = MultipleNumericalChoices / SingleNumericalAnswer

MultipleNumericalChoices "Multiple Numerical Choices"
  = choices:(NumericalChoice)+ { return choices; }

NumericalChoice "Numerical Choice"
  = _ choice:([=~] Weight? SingleNumericalAnswer?) _ feedback:Feedback? _ 
    { var symbol = choice[0];
      var wt = choice[1];
      var txt = choice[2];
      var choice = { isCorrect:(symbol == '='), 
                     weight:wt, 
                     text: (txt !== null ? txt : {format:getLastQuestionTextFormat(), text:'*'}), // Moodle unit tests show this, not in documentation
                     feedback: feedback }; 
      return choice } 

SingleNumericalAnswer "Single numeric answer"
  = NumberWithRange / NumberHighLow / NumberAlone

NumberWithRange "(number with range)"
  = number:Number ':' range:Number 
  { var numericAnswer = {type: 'range', number: number, range:range}; return numericAnswer}

NumberHighLow "(number with high-low)"
  = numberLow:Number '..' numberHigh:Number 
  { var numericAnswer = {type: 'high-low', numberHigh: numberHigh, numberLow:numberLow}; return numericAnswer}

NumberAlone "(number answer)"
  = number:Number
  { var numericAnswer = {type: 'simple', number: number}; return numericAnswer}  

//////////////
QuestionTitle ":: Title ::"
  = '::' title:TitleText+ '::' { return escapedCharacterDecode(title.join('')) }
  
QuestionStem "Question stem"
  = stem:RichText 
    { setLastQuestionTextFormat(stem.format); // save format for question, for default of other non-formatted text
      return stem }

QuestionSeparator "(blank lines separator)"
  = Space* (BlankLines  
    / EndOfLine? EndOfFile)

BlankLines "(blank lines)"
  = EndOfLine BlankLine+

BlankLine "blank line"
  = Space* EndOfLine

TitleText "(Title text)"
  = !'::' t:(EscapeSequence / UnescapedChar) {return t}

TextChar "(text character)"
  = (UnescapedChar / EscapeSequence / EscapeChar)

MatchTextChar "(text character)"
  = (UnescapedMatchChar / EscapeSequence / EscapeChar)

Format "format"
  = '[' format:('html' /
                'markdown' /
                'plain' / 
                'moodle') 
    ']' {return format}

EscapeChar "(escape character)"
  = '\\' 

EscapeSequence "escape sequence"
  = "\\" char: ("\\" / ":" / "#" / "=" / "{" / "}" / "~" / "n") {
    return escapedCharacters['\\' + char];
    }

// return the text if it's not escaped
UnescapedChar ""
  = !(EscapeSequence / ControlChar / QuestionSeparator) . {return text()}

// return the text if it's not escaped
UnescapedMatchChar ""
  = !(EscapeSequence / ControlChar / '->' / QuestionSeparator) . {return text()}

ControlChar 
  = '=' / '~' / "#" / '{' / '}' / '\\' / ':'

MatchRichText "(formatted text excluding '->')"
  = format:Format? _ txt:MatchTextChar+ { return formattedText(format, txt) } 

RichText "(formatted text)"
  = format:Format? _ txt:TextChar+ { return formattedText(format, txt) } 

PlainText "(unformatted text)"
  = txt:TextChar+ { return removeNewLinesDuplicateSpaces(txt.join('').trim())} 

CategoryText "(category text)"
  = txt:(!EndOfLine .)* &(EndOfLine / EndOfFile) { return txt.flat().join('') } 

Number
  = Sign? DecimalValue { return parseFloat(text()); }

DecimalValue
  = Digits ('.' Digits)?

Digits
  = [0-9]+

Sign
  = [+-]

GlobalFeedback
    = '####' _ rt:RichText _ {return rt;}

_ "(single line whitespace)"
  = (Space / EndOfLine !BlankLine)*

__ "(multiple line whitespace)"
  = (TagComment / EndOfLine / Space )*

ResetIdsTags 
  = &' '*     // useless match to reset any previously parsed tags/ids
    {questionId = null; questionTags = null}

Comment "(comment)"
  = '//' p:([^\n\r]*)
 {return null}

TagComment "(comment)"
  = '//' p:([^\n\r]*)
  {
    var comment = p.join("");
    // use a regex like the Moodle parser
    var idIsFound = comment.match(/\[id:([^\x00-\x1F\x7F]+?)]/); 
    if(idIsFound) {
        questionId = idIsFound[1].trim().replace('\\]', ']');
    }
    
    // use a regex like the Moodle parser
    var tagMatches = comment.matchAll(/\[tag:([^\x00-\x1F\x7F]+?)]/g);
    Array.from(
      comment.matchAll(/\[tag:([^\x00-\x1F\x7F]+?)]/g), 
                       function(m) { return m[1] })
              .forEach(function(element) {
                if(!questionTags) questionTags = [];
                questionTags.push(element);
              });
    return null // hacking, must "reset" values each time a partial match happens
  }

Space "(space)"
  = ' ' / '\t'
EndOfLine "(end of line)"
  = '\r\n' / '\n' / '\r'
EndOfFile 
  = !. { return "EOF"; }
