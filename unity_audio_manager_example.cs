using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Example Unity script to receive and play audio chunks from Flutter
/// Attach this to a GameObject named "AudioManager" in your Unity scene
/// </summary>
public class AudioManager : MonoBehaviour
{
    private AudioSource audioSource;
    private List<byte[]> audioChunks = new List<byte[]>();
    private bool isReceivingAudio = false;
    private const int sampleRate = 24000; // PCM 24kHz from ElevenLabs
    private const int channels = 1; // Mono audio

    void Start()
    {
        // Get or add AudioSource component
        audioSource = GetComponent<AudioSource>();
        if (audioSource == null)
        {
            audioSource = gameObject.AddComponent<AudioSource>();
        }

        audioSource.playOnAwake = false;
    }

    /// <summary>
    /// Called from Flutter when audio chunks are received
    /// Message format: "START" | "CHUNK|base64data" | "END"
    /// </summary>
    public void OnAudioChunk(string message)
    {
        Debug.Log($"Received audio message: {message.Substring(0, Math.Min(50, message.Length))}...");

        if (message == "START")
        {
            // Clear previous audio data
            audioChunks.Clear();
            isReceivingAudio = true;
            Debug.Log("Started receiving audio chunks");
        }
        else if (message == "END")
        {
            // All chunks received, process and play
            isReceivingAudio = false;
            Debug.Log($"Finished receiving {audioChunks.Count} audio chunks");
            ProcessAndPlayAudio();
        }
        else if (message.StartsWith("CHUNK|"))
        {
            // Extract base64 data and decode
            string base64Data = message.Substring(6); // Remove "CHUNK|" prefix
            try
            {
                byte[] audioData = Convert.FromBase64String(base64Data);
                audioChunks.Add(audioData);
                Debug.Log($"Received chunk {audioChunks.Count}, size: {audioData.Length} bytes");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to decode audio chunk: {e.Message}");
            }
        }
    }

    /// <summary>
    /// Called from Flutter when an error occurs
    /// </summary>
    public void OnAudioError(string error)
    {
        Debug.LogError($"Audio error from Flutter: {error}");
        audioChunks.Clear();
        isReceivingAudio = false;
    }

    /// <summary>
    /// Combines all audio chunks and creates an AudioClip for playback
    /// PCM data is directly converted to float samples - no conversion overhead
    /// </summary>
    private void ProcessAndPlayAudio()
    {
        if (audioChunks.Count == 0)
        {
            Debug.LogWarning("No audio chunks to process");
            return;
        }

        // Combine all chunks into one byte array
        int totalSize = 0;
        foreach (var chunk in audioChunks)
        {
            totalSize += chunk.Length;
        }

        byte[] completeAudioData = new byte[totalSize];
        int position = 0;
        foreach (var chunk in audioChunks)
        {
            Buffer.BlockCopy(chunk, 0, completeAudioData, position, chunk.Length);
            position += chunk.Length;
        }

        Debug.Log($"Combined PCM audio data: {completeAudioData.Length} bytes");

        // Convert PCM bytes directly to AudioClip
        AudioClip clip = ConvertPCMToAudioClip(completeAudioData);
        PlayAudioWithLipSync(clip);
    }

    /// <summary>
    /// Converts PCM 16-bit byte array directly to Unity AudioClip
    /// No file I/O or conversion overhead
    /// </summary>
    private AudioClip ConvertPCMToAudioClip(byte[] pcmData)
    {
        // PCM is 16-bit (2 bytes per sample)
        int sampleCount = pcmData.Length / 2;

        // Create AudioClip
        float duration = (float)sampleCount / sampleRate;
        AudioClip audioClip = AudioClip.Create("ElevenLabsAudio", sampleCount, channels, sampleRate, false);

        // Convert 16-bit PCM to float samples (-1.0 to 1.0)
        float[] samples = new float[sampleCount];
        for (int i = 0; i < sampleCount; i++)
        {
            // Read 16-bit signed integer (little-endian)
            short pcmSample = (short)(pcmData[i * 2] | (pcmData[i * 2 + 1] << 8));
            // Normalize to -1.0 to 1.0
            samples[i] = pcmSample / 32768f;
        }

        // Set the data to the AudioClip
        audioClip.SetData(samples, 0);

        Debug.Log($"Created AudioClip: {duration:F2} seconds, {sampleCount} samples");
        return audioClip;
    }

    /// <summary>
    /// Play audio and trigger lip sync
    /// </summary>
    private void PlayAudioWithLipSync(AudioClip clip)
    {
        audioSource.clip = clip;
        audioSource.Play();

        Debug.Log($"Playing audio clip: {clip.length} seconds");

        // TODO: Add your lip sync logic here
        // You can use:
        // - audioSource.GetOutputData() for amplitude
        // - audioSource.GetSpectrumData() for frequency analysis
        // - Or integrate with a lip sync solution like Oculus Lipsync, SALSA, etc.

        StartCoroutine(LipSyncCoroutine(clip.length));
    }

    /// <summary>
    /// Example lip sync coroutine
    /// Replace with your actual lip sync implementation
    /// </summary>
    private IEnumerator LipSyncCoroutine(float duration)
    {
        float elapsed = 0f;
        float[] samples = new float[256];

        while (elapsed < duration && audioSource.isPlaying)
        {
            // Get current audio data
            audioSource.GetOutputData(samples, 0);

            // Calculate volume/amplitude
            float sum = 0f;
            for (int i = 0; i < samples.Length; i++)
            {
                sum += Mathf.Abs(samples[i]);
            }
            float volume = sum / samples.Length;

            // Use volume to drive mouth animation
            // Example: blend shape or bone rotation
            Debug.Log($"Current volume: {volume}");

            // TODO: Apply to your character's mouth/jaw
            // characterBlendShapes["MouthOpen"] = volume * 100f;

            elapsed += Time.deltaTime;
            yield return null;
        }

        Debug.Log("Lip sync finished");
    }
}
