In my understanding it should be SYSTEM, USER, REASONING, OUTPUT. 

SYSTEM should be the task description from Graphiti
USER should the data of the specific task
REASONING should be self-prompting by the LLM without any task-specific data.
OUTPUT should be the just the data processed according to the system prompt

What we do is capture REASONING  and append it directly after USER data. Then when the model goes to reason, it sees that most of the reasoning is already there, so it goes straight to completion UNLESS it saw something in the data that needed more reasoning. If there is new reasoning, we capture that trace too and add it to Graphiti as a new segment in the reasoning thread.

V3 should be to ensure that the whole reasoning thread is consolidated into just one injection; we believe graphiti's existing tools already equip us for this meta-reasoning task, but we will need to make sure that it doesn't just mangle the reasoning. 

I want to eliminate the duplication but I am not sure if Graphiti follows the usage I expect and explain above. If Graphiti's usage is different then we need to adapt. Either way the full loop should be new pressure only from the data, and if there is nothing surprising then the LLM performs minimal reasoning and just processes the output. - We still need to ensure that there are embeddings between SYSTEM and REASONING trace, so that an appropriate reasoning trace can be injected if there is a task that has not had reasoning captured before.

If we find that REASONING is reproducing data from USER, then this is a major wrench in our gears. If that is happening then we need to change the system prompt from Graphiti to instruct the model to only reason about the framing of the task and not mention specific data in the reasoning, and also include it as part of the V3 task to remove task-specific data from the stored reasoning traces.

---

Here are some tips on how to improve the prompts.

This information is used to construct a knowledge graph where nodes are connected by nodes and edges. When you think, only talk about the keys like "source_entity_name" in key-value pairs. Reason about the keys and not directly about the values associated with the keys. When thinking is complete you can talk about both keys and the values of the key-value pairs directly.

---

 now we do a post-mortem on the negative results. The expectation was that the model would be duplicating a lot of its reasoning steps and that its mode of reasoning would be characteristic of the specific local model, and that this reasoning trace would not be fully meaningful to another very different model. We expected that we could cache some default meta-reasoning which would have to be of such a high quality and so fully generic that this would have worked like a fully "unrolled loop" opimization which it coul apply like a generic template to that type of task, and that future iterations of template+new reasoning + scrubbing + compaction would have improved on the task-specific template. 

We didn't implement compaction, although this could have been done simultaneously with scrubbing, if given the right prompt. 

What else do we need to observe about why the experiment proved unsuccessful?

---

Need to make sure; we should not be capturing traces about compaction or anything meta-level. We don't need that level of recursion.

When you say 95% reduction are you talking about reduction of the the trace that is stored as a template or reduction of the reasoning that follows an injection? Reducing the trace but not the reasoing is not a very useful thing to measure. 

Also I have seen the model drop down to just 5 tokens per second, so just measuring post-injection reasoning trace isn't representative of performance either. It is reasoning time that we need to measure and base our decisions on. Trace lengths are just supporting information to time taken. - Quality is a separate concern.
